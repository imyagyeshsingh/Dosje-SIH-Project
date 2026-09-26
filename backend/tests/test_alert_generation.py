from datetime import datetime
from decimal import Decimal
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.ai_detection import AIDetection
from app.models.alert import Alert
from app.models.attendance import Attendance
from app.models.audit_log import AuditLog
from app.models.camera import Camera
from app.models.notification import Notification
from app.models.project import Project
from app.services.alert_service import generate_project_alerts


@pytest.fixture
def client_and_db():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    Base.metadata.create_all(bind=engine)

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client, TestingSessionLocal
    app.dependency_overrides.clear()
    Base.metadata.drop_all(bind=engine)


def create_project(session, progress: Decimal = Decimal("50"), status: str = "ACTIVE") -> Project:
    project = Project(
        project_name="Project A",
        project_code=f"PROJ-A-{uuid4().hex[:8].upper()}",
        status=status,
        progress=progress,
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def create_camera(session, project_id: int, status: str = "ACTIVE") -> Camera:
    camera = Camera(
        project_id=project_id,
        camera_name="Main Camera",
        stream_url="rtsp://example/stream",
        status=status,
    )
    session.add(camera)
    session.commit()
    session.refresh(camera)
    return camera


def create_detection(
    session,
    project_id: int,
    camera_id: int,
    *,
    people_detected: int = 17,
    activity: str = "NORMAL",
    confidence: Decimal = Decimal("0.94"),
    timestamp: datetime | None = None,
) -> AIDetection:
    detection = AIDetection(
        project_id=project_id,
        camera_id=camera_id,
        people_detected=people_detected,
        activity=activity,
        confidence=confidence,
        timestamp=timestamp or datetime(2026, 9, 20, 5, 0, 0),
    )
    session.add(detection)
    session.commit()
    session.refresh(detection)
    return detection


def create_attendance(session, project_id: int, expected_workers: int = 20) -> Attendance:
    attendance = Attendance(project_id=project_id, expected_workers=expected_workers)
    session.add(attendance)
    session.commit()
    session.refresh(attendance)
    return attendance


def test_risk_high_creates_high_risk_alert(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db, progress=Decimal("0"))
        camera = create_camera(db, project.id, status="ACTIVE")
        create_detection(db, project.id, camera.id, activity="SUSPICIOUS", confidence=Decimal("0.95"))

        alerts = generate_project_alerts(project.id, db)

        risk_alert = next(alert for alert in alerts if alert.alert_type == "RISK")
        assert risk_alert.severity == "HIGH"
        assert risk_alert.message == "Project risk level is HIGH"
        assert risk_alert.source == "RISK_ENGINE"
        assert risk_alert.status == "OPEN"
    finally:
        db.close()


def test_risk_critical_creates_critical_risk_alert(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db, progress=Decimal("0"))
        camera = create_camera(db, project.id, status="INACTIVE")
        create_detection(db, project.id, camera.id, activity="SUSPICIOUS", confidence=Decimal("0.95"))

        alerts = generate_project_alerts(project.id, db)

        critical = next(alert for alert in alerts if alert.alert_type == "RISK")
        assert critical.severity == "CRITICAL"
        assert critical.message == "Project risk level is CRITICAL"
    finally:
        db.close()


def test_low_or_medium_risk_creates_no_risk_alert(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db, progress=Decimal("90"))
        create_camera(db, project.id, status="ACTIVE")

        alerts = generate_project_alerts(project.id, db)

        assert not any(alert.alert_type == "RISK" for alert in alerts)
    finally:
        db.close()


def test_ai_suspicious_creates_high_alert_with_detection_details(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)
        detection = create_detection(
            db,
            project.id,
            camera.id,
            activity=" suspicious ",
            confidence=Decimal("0.87"),
        )

        alerts = generate_project_alerts(project.id, db)

        ai_alert = next(alert for alert in alerts if alert.alert_type == "AI_ACTIVITY")
        assert ai_alert.severity == "HIGH"
        assert ai_alert.message == "Suspicious activity detected by AI"
        assert ai_alert.source == "AI_DETECTION"
        assert ai_alert.detection_id == detection.id
        assert float(ai_alert.confidence) == 0.87
    finally:
        db.close()


def test_ai_high_creates_high_alert(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)
        create_detection(db, project.id, camera.id, activity=" HIGH ", confidence=Decimal("0.81"))

        alerts = generate_project_alerts(project.id, db)

        ai_alert = next(alert for alert in alerts if alert.alert_type == "AI_ACTIVITY")
        assert ai_alert.severity == "HIGH"
        assert ai_alert.message == "High-risk activity detected by AI"
    finally:
        db.close()


def test_ai_no_activity_creates_medium_alert(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)
        create_detection(db, project.id, camera.id, activity=" no_activity ")

        alerts = generate_project_alerts(project.id, db)

        ai_alert = next(alert for alert in alerts if alert.alert_type == "AI_ACTIVITY")
        assert ai_alert.severity == "MEDIUM"
        assert ai_alert.message == "No activity detected by AI"
    finally:
        db.close()


def test_ai_normal_creates_no_alert(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)
        create_detection(db, project.id, camera.id, activity="NORMAL")

        alerts = generate_project_alerts(project.id, db)

        assert not any(alert.alert_type == "AI_ACTIVITY" for alert in alerts)
    finally:
        db.close()


def test_attendance_below_50_creates_high_alert(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)
        create_attendance(db, project.id, expected_workers=20)
        create_detection(db, project.id, camera.id, people_detected=3, activity="NORMAL")

        alerts = generate_project_alerts(project.id, db)

        attendance_alert = next(alert for alert in alerts if alert.alert_type == "ATTENDANCE")
        assert attendance_alert.severity == "HIGH"
        assert attendance_alert.message == "Attendance is below 50%"
        assert attendance_alert.source == "ATTENDANCE_ENGINE"
    finally:
        db.close()


def test_attendance_50_to_74_99_creates_medium_alert(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)
        create_attendance(db, project.id, expected_workers=20)
        create_detection(db, project.id, camera.id, people_detected=12, activity="NORMAL")

        alerts = generate_project_alerts(project.id, db)

        attendance_alert = next(alert for alert in alerts if alert.alert_type == "ATTENDANCE")
        assert attendance_alert.severity == "MEDIUM"
        assert attendance_alert.message == "Attendance is below 75%"
    finally:
        db.close()


def test_attendance_75_plus_creates_no_alert(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)
        create_attendance(db, project.id, expected_workers=20)
        create_detection(db, project.id, camera.id, people_detected=15, activity="NORMAL")

        alerts = generate_project_alerts(project.id, db)

        assert not any(alert.alert_type == "ATTENDANCE" for alert in alerts)
    finally:
        db.close()


def test_attendance_missing_config_or_detection_creates_no_alert(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        alerts_without_config = generate_project_alerts(project.id, db)
        assert not any(alert.alert_type == "ATTENDANCE" for alert in alerts_without_config)

        create_attendance(db, project.id, expected_workers=20)
        alerts_without_detection = generate_project_alerts(project.id, db)
        assert not any(alert.alert_type == "ATTENDANCE" for alert in alerts_without_detection)

        create_detection(db, project.id, camera.id, people_detected=0, activity="NORMAL")
        alerts_after_detection = generate_project_alerts(project.id, db)
        assert any(alert.alert_type == "ATTENDANCE" for alert in alerts_after_detection)
    finally:
        db.close()


def test_cctv_below_50_creates_critical_alert(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        create_camera(db, project.id, status="ACTIVE")
        create_camera(db, project.id, status="INACTIVE")
        create_camera(db, project.id, status="OFFLINE")

        alerts = generate_project_alerts(project.id, db)

        camera_alert = next(alert for alert in alerts if alert.alert_type == "CAMERA")
        assert camera_alert.severity == "CRITICAL"
        assert camera_alert.message == "Less than 50% of project cameras are active"
        assert camera_alert.source == "CAMERA_MONITOR"
    finally:
        db.close()


def test_cctv_50_to_74_99_creates_high_alert(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        create_camera(db, project.id, status="ACTIVE")
        create_camera(db, project.id, status="OFFLINE")

        alerts = generate_project_alerts(project.id, db)

        camera_alert = next(alert for alert in alerts if alert.alert_type == "CAMERA")
        assert camera_alert.severity == "HIGH"
        assert camera_alert.message == "Less than 75% of project cameras are active"
    finally:
        db.close()


def test_cctv_75_plus_no_alert(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        create_camera(db, project.id, status="ACTIVE")
        create_camera(db, project.id, status="ACTIVE")
        create_camera(db, project.id, status="ACTIVE")
        create_camera(db, project.id, status="OFFLINE")

        alerts = generate_project_alerts(project.id, db)

        assert not any(alert.alert_type == "CAMERA" for alert in alerts)
    finally:
        db.close()


def test_zero_cameras_creates_no_camera_alert(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)

        alerts = generate_project_alerts(project.id, db)

        assert not any(alert.alert_type == "CAMERA" for alert in alerts)
    finally:
        db.close()


def test_duplicate_open_alerts_are_not_created_twice(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db, progress=Decimal("90"))
        camera = create_camera(db, project.id, status="ACTIVE")
        create_detection(db, project.id, camera.id, activity="SUSPICIOUS", confidence=Decimal("0.95"))

        first_run = generate_project_alerts(project.id, db)
        second_run = generate_project_alerts(project.id, db)

        assert len(first_run) >= 1
        assert second_run == []

        alert_audit_count = db.query(AuditLog).filter(
            AuditLog.project_id == project.id,
            AuditLog.entity_type == "ALERT",
            AuditLog.action == "CREATED",
        ).count()
        assert alert_audit_count >= 1

        existing = db.query(Alert).filter_by(project_id=project.id, alert_type="AI_ACTIVITY").first()
        existing.status = "RESOLVED"
        db.commit()

        third_run = generate_project_alerts(project.id, db)
        assert any(alert.alert_type == "AI_ACTIVITY" for alert in third_run)

        alert_notifications = db.query(Notification).filter(Notification.project_id == project.id).count()
        assert alert_notifications >= 1
    finally:
        db.close()


def test_generate_alerts_endpoint_validates_project_and_returns_generated_alerts(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db, progress=Decimal("0"))
        camera = create_camera(db, project.id, status="ACTIVE")
        create_detection(db, project.id, camera.id, activity="SUSPICIOUS", confidence=Decimal("0.95"))

        response = client.post(f"/alerts/generate/{project.id}")

        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 1
        assert any(item["alert_type"] in {"RISK", "AI_ACTIVITY"} for item in data)
    finally:
        db.close()


def test_generate_alerts_endpoint_returns_404_for_missing_project(client_and_db):
    client, _ = client_and_db

    response = client.post("/alerts/generate/99999")

    assert response.status_code == 404


def test_generate_alerts_endpoint_returns_empty_list_when_no_conditions_trigger(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db, progress=Decimal("90"))
        create_camera(db, project.id, status="ACTIVE")

        response = client.post(f"/alerts/generate/{project.id}")

        assert response.status_code == 200
        assert response.json() == []
    finally:
        db.close()


def test_existing_risk_and_project_summary_still_work(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db, progress=Decimal("0"))
        camera = create_camera(db, project.id, status="ACTIVE")
        create_detection(db, project.id, camera.id, activity="SUSPICIOUS", confidence=Decimal("0.95"))

        risk_response = client.get(f"/risk/{project.id}")
        assert risk_response.status_code == 200
        assert risk_response.json()["level"] in {"HIGH", "CRITICAL"}

        summary_response = client.get(f"/projects/{project.id}/summary")
        assert summary_response.status_code == 200
        assert summary_response.json()["project"]["id"] == project.id
    finally:
        db.close()


def test_project_summary_alert_counts_are_db_derived(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        other_project = create_project(db)
        db.add_all(
            [
                Alert(project_id=project.id, alert_type="RISK", severity="HIGH", message="open", status="OPEN", source="RISK_ENGINE"),
                Alert(project_id=project.id, alert_type="AI_ACTIVITY", severity="HIGH", message="ack", status="ACKNOWLEDGED", source="AI_DETECTION"),
                Alert(project_id=project.id, alert_type="ATTENDANCE", severity="MEDIUM", message="resolved", status="RESOLVED", source="ATTENDANCE_ENGINE"),
                Alert(project_id=other_project.id, alert_type="CAMERA", severity="CRITICAL", message="other", status="OPEN", source="CAMERA_MONITOR"),
            ]
        )
        db.commit()

        response = client.get(f"/projects/{project.id}/summary")

        assert response.status_code == 200
        data = response.json()
        assert data["alerts"]["total"] == 3
        assert data["alerts"]["active"] == 2
    finally:
        db.close()


def test_existing_ai_attendance_and_cctv_endpoints_still_work(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)
        create_attendance(db, project.id, expected_workers=10)
        create_detection(db, project.id, camera.id, people_detected=8, activity="NORMAL")

        ai_response = client.get(f"/ai/detection/{project.id}/summary")
        assert ai_response.status_code == 200

        attendance_response = client.get(f"/attendance/summary/{project.id}")
        assert attendance_response.status_code == 200

        cctv_response = client.get(f"/cctv/project/{project.id}")
        assert cctv_response.status_code == 200
        assert len(cctv_response.json()) == 1
    finally:
        db.close()
