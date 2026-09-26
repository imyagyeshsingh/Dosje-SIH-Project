from datetime import datetime, timedelta, timezone
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.ai_detection import AIDetection
from app.models.alert import Alert
from app.models.attendance import Attendance
from app.models.camera import Camera
from app.models.project import Project
from app.routers.attendance import get_latest_detection
from app.routers.risk import calculate_project_risk
from app.services.audit_log_service import create_audit_log
from app.services.notification_service import notify_alert

# ---------------------------------------------------------------------------
# Camera staleness threshold (Task 20)
# A camera with status ACTIVE whose last_active timestamp is older than this
# duration will generate a MEDIUM CAMERA alert.  Defined once here; never
# inline-duplicated elsewhere in this module.
# ---------------------------------------------------------------------------
CAMERA_STALE_THRESHOLD = timedelta(minutes=15)


def _get_or_none_project(project_id: int, db: Session) -> Project | None:
    return db.get(Project, project_id)


def _build_alert(
    *,
    project_id: int,
    alert_type: str,
    severity: str,
    message: str,
    source: str,
    db: Session,
    detection_id: int | None = None,
    confidence: Decimal | None = None,
) -> Alert | None:
    existing = db.scalar(
        select(Alert.id)
        .where(
            Alert.project_id == project_id,
            Alert.alert_type == alert_type,
            Alert.source == source,
            Alert.message == message,
            Alert.status == "OPEN",
        )
        .limit(1)
    )
    if existing is not None:
        return None

    alert = Alert(
        project_id=project_id,
        alert_type=alert_type,
        severity=severity,
        message=message,
        confidence=confidence,
        source=source,
        detection_id=detection_id,
        status="OPEN",
    )
    db.add(alert)
    return alert


def _ai_activity_alert_for_detection(detection: AIDetection | None, db: Session, project_id: int) -> Alert | None:
    if detection is None:
        return None

    normalized_activity = (detection.activity or "").strip().upper()
    if normalized_activity in {"SUSPICIOUS", "HIGH"}:
        message = "Suspicious activity detected by AI" if normalized_activity == "SUSPICIOUS" else "High-risk activity detected by AI"
        return _build_alert(
            project_id=project_id,
            alert_type="AI_ACTIVITY",
            severity="HIGH",
            message=message,
            source="AI_DETECTION",
            db=db,
            detection_id=detection.id,
            confidence=detection.confidence,
        )
    if normalized_activity == "NO_ACTIVITY":
        return _build_alert(
            project_id=project_id,
            alert_type="AI_ACTIVITY",
            severity="MEDIUM",
            message="No activity detected by AI",
            source="AI_DETECTION",
            db=db,
            detection_id=detection.id,
            confidence=detection.confidence,
        )
    return None


def _attendance_alert_for_project(project_id: int, db: Session) -> Alert | None:
    attendance = db.scalars(select(Attendance).where(Attendance.project_id == project_id)).first()
    detection = get_latest_detection(project_id, db)

    if attendance is None or detection is None:
        return None

    expected_workers = attendance.expected_workers
    if expected_workers is None or expected_workers <= 0:
        return None

    if detection.people_detected is None:
        return None

    attendance_percentage = (detection.people_detected / expected_workers) * 100
    if attendance_percentage < 50:
        return _build_alert(
            project_id=project_id,
            alert_type="ATTENDANCE",
            severity="HIGH",
            message="Attendance is below 50%",
            source="ATTENDANCE_ENGINE",
            db=db,
        )
    if attendance_percentage < 75:
        return _build_alert(
            project_id=project_id,
            alert_type="ATTENDANCE",
            severity="MEDIUM",
            message="Attendance is below 75%",
            source="ATTENDANCE_ENGINE",
            db=db,
        )
    return None


def _camera_alert_for_project(project_id: int, db: Session) -> Alert | None:
    total_cameras = db.scalar(
        select(func.count()).select_from(Camera).where(Camera.project_id == project_id)
    )
    if total_cameras is None or total_cameras == 0:
        return None

    active_cameras = db.scalar(
        select(func.count()).select_from(Camera).where(
            Camera.project_id == project_id,
            Camera.status == "ACTIVE",
        )
    ) or 0

    availability = (active_cameras / total_cameras) * 100
    if availability < 50:
        return _build_alert(
            project_id=project_id,
            alert_type="CAMERA",
            severity="CRITICAL",
            message="Less than 50% of project cameras are active",
            source="CAMERA_MONITOR",
            db=db,
        )
    if availability < 75:
        return _build_alert(
            project_id=project_id,
            alert_type="CAMERA",
            severity="HIGH",
            message="Less than 75% of project cameras are active",
            source="CAMERA_MONITOR",
            db=db,
        )
    return None


def _camera_stale_alerts_for_project(project_id: int, db: Session) -> list[Alert]:
    """Return one MEDIUM CAMERA alert for each ACTIVE camera whose last_active
    timestamp is older than CAMERA_STALE_THRESHOLD.

    Cameras with NULL last_active are intentionally skipped: a NULL value means
    the camera has never been activated via the API since registration, so it has
    no activity baseline from which staleness can be measured.  The existing
    availability check (_camera_alert_for_project) already handles cameras that
    have never been set ACTIVE.

    Deduplication is handled by _build_alert(): if an OPEN alert with the same
    (project_id, alert_type, source, message) already exists, _build_alert returns
    None and no duplicate is created.  Because the message includes the camera
    name, deduplication is correctly per-camera, not per-project.
    """
    now_utc = datetime.now(timezone.utc)
    stale_cutoff = now_utc - CAMERA_STALE_THRESHOLD

    stale_cameras = db.scalars(
        select(Camera).where(
            Camera.project_id == project_id,
            Camera.status == "ACTIVE",
            Camera.last_active.isnot(None),
            Camera.last_active < stale_cutoff,
        )
    ).all()

    alerts: list[Alert] = []
    for camera in stale_cameras:
        alert = _build_alert(
            project_id=project_id,
            alert_type="CAMERA",
            severity="MEDIUM",
            message=(
                f'Camera "{camera.camera_name}" has not reported activity '
                f"in the last {int(CAMERA_STALE_THRESHOLD.total_seconds() // 60)} minutes"
            ),
            source="CAMERA_MONITOR",
            db=db,
        )
        if alert is not None:
            alerts.append(alert)
    return alerts


def generate_project_alerts(project_id: int, db: Session) -> list[Alert]:
    # Acquire a row-level lock on the project to serialise concurrent alert
    # generation for the same project.  This prevents the check-then-act race
    # in _build_alert() where two requests could both see no existing OPEN
    # alert and both insert a duplicate.  The lock is released on commit/rollback.
    project = db.scalar(
        select(Project).where(Project.id == project_id).with_for_update()
    )
    if project is None:
        raise ValueError("Project not found")

    risk_response = calculate_project_risk(project, db)
    new_alerts: list[Alert] = []

    if risk_response.level == "HIGH":
        risk_alert = _build_alert(
            project_id=project_id,
            alert_type="RISK",
            severity="HIGH",
            message="Project risk level is HIGH",
            source="RISK_ENGINE",
            db=db,
        )
        if risk_alert is not None:
            new_alerts.append(risk_alert)
    elif risk_response.level == "CRITICAL":
        risk_alert = _build_alert(
            project_id=project_id,
            alert_type="RISK",
            severity="CRITICAL",
            message="Project risk level is CRITICAL",
            source="RISK_ENGINE",
            db=db,
        )
        if risk_alert is not None:
            new_alerts.append(risk_alert)

    latest_detection = get_latest_detection(project_id, db)
    ai_alert = _ai_activity_alert_for_detection(latest_detection, db, project_id)
    if ai_alert is not None:
        new_alerts.append(ai_alert)

    attendance_alert = _attendance_alert_for_project(project_id, db)
    if attendance_alert is not None:
        new_alerts.append(attendance_alert)

    camera_alert = _camera_alert_for_project(project_id, db)
    if camera_alert is not None:
        new_alerts.append(camera_alert)

    # Task 20: per-camera staleness check — reuses existing alert/notify/audit flow.
    stale_alerts = _camera_stale_alerts_for_project(project_id, db)
    new_alerts.extend(stale_alerts)

    if not new_alerts:
        return []

    db.commit()
    for alert in new_alerts:
        db.refresh(alert)
        create_audit_log(
            db=db,
            project_id=alert.project_id,
            entity_type="ALERT",
            entity_id=alert.id,
            action="CREATED",
        )

    for alert in new_alerts:
        notify_alert(alert, db)

    return new_alerts
