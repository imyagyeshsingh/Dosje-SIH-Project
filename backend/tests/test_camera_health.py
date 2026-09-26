"""
tests/test_camera_health.py — Task 20: Camera Health Automation

Tests A–H covering stale-camera detection via generate_project_alerts().

No external dependencies (no freezegun).  Timestamps are set directly on
model fields using explicit datetime values.

Fixture pattern mirrors test_ai_api.py: SQLite in-memory database, isolated
FastAPI app that excludes the Report/EvidenceReference mapper to avoid the
pre-existing Task 18 mapper issue.
"""

from datetime import datetime, timedelta, timezone
from decimal import Decimal
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.models.alert import Alert
from app.models.audit_log import AuditLog
from app.models.camera import Camera
from app.models.notification import Notification
from app.models.project import Project
from app.routers.alerts import router as alerts_router
from app.routers.attendance import router as attendance_router
from app.routers.cctv import router as cctv_router
from app.routers.projects import router as projects_router
from app.routers.risk import router as risk_router
from app.services.alert_service import (
    CAMERA_STALE_THRESHOLD,
    generate_project_alerts,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_STALE_DELTA = CAMERA_STALE_THRESHOLD + timedelta(minutes=5)  # clearly beyond threshold
_FRESH_DELTA = CAMERA_STALE_THRESHOLD - timedelta(minutes=5)  # clearly within threshold


def _now() -> datetime:
    return datetime.now(timezone.utc)


# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------

def _create_app() -> FastAPI:
    """Minimal FastAPI app — excludes Report router to avoid pre-existing mapper issue."""
    app = FastAPI(title="DoSJE Test App - Camera Health")
    app.include_router(projects_router)
    app.include_router(cctv_router)
    app.include_router(attendance_router)
    app.include_router(alerts_router)
    app.include_router(risk_router)
    return app


@pytest.fixture
def db_session():
    """Provide an isolated SQLite in-memory session for each test."""
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    Base.metadata.create_all(bind=engine)

    session: Session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


# ---------------------------------------------------------------------------
# Small model builders
# ---------------------------------------------------------------------------

def _make_project(db: Session) -> Project:
    project = Project(
        project_name="Health Test Project",
        project_code=f"HP-{uuid4().hex[:8].upper()}",
        status="ACTIVE",
        progress=Decimal("50"),
    )
    db.add(project)
    db.commit()
    db.refresh(project)
    return project


def _make_camera(
    db: Session,
    project_id: int,
    *,
    name: str = "Cam-1",
    status: str = "ACTIVE",
    last_active: datetime | None = None,
) -> Camera:
    camera = Camera(
        project_id=project_id,
        camera_name=name,
        stream_url="rtsp://example.com/stream",
        status=status,
        last_active=last_active,
    )
    db.add(camera)
    db.commit()
    db.refresh(camera)
    return camera


# ---------------------------------------------------------------------------
# Test A — Fresh camera produces NO stale alert
# ---------------------------------------------------------------------------

def test_A_fresh_camera_no_stale_alert(db_session):
    """A camera whose last_active is within the threshold must NOT generate
    a stale alert."""
    db = db_session
    project = _make_project(db)
    _make_camera(db, project.id, name="Fresh-Cam", last_active=_now() - _FRESH_DELTA)

    alerts = generate_project_alerts(project.id, db)

    stale_alerts = [
        a for a in alerts
        if "has not reported activity" in (a.message or "")
    ]
    assert stale_alerts == [], (
        f"Expected no stale alert for a fresh camera, but got: {stale_alerts}"
    )


# ---------------------------------------------------------------------------
# Test B — Stale camera produces a MEDIUM CAMERA alert
# ---------------------------------------------------------------------------

def test_B_stale_camera_creates_medium_camera_alert(db_session):
    """A camera whose last_active is beyond the threshold should generate
    exactly one MEDIUM-severity CAMERA alert."""
    db = db_session
    project = _make_project(db)
    camera = _make_camera(db, project.id, name="Stale-Cam", last_active=_now() - _STALE_DELTA)

    alerts = generate_project_alerts(project.id, db)

    stale_alerts = [
        a for a in alerts
        if "has not reported activity" in (a.message or "")
    ]
    assert len(stale_alerts) == 1, f"Expected 1 stale alert, got {len(stale_alerts)}"

    alert = stale_alerts[0]
    assert alert.alert_type == "CAMERA", f"Expected alert_type CAMERA, got {alert.alert_type}"
    assert alert.severity == "MEDIUM", f"Expected severity MEDIUM, got {alert.severity}"
    assert alert.source == "CAMERA_MONITOR", f"Expected source CAMERA_MONITOR, got {alert.source}"
    assert camera.camera_name in alert.message, "Alert message should contain the camera name"
    assert alert.status == "OPEN", f"Expected status OPEN, got {alert.status}"


# ---------------------------------------------------------------------------
# Test C — Deduplication: second call does not create a duplicate open alert
# ---------------------------------------------------------------------------

def test_C_deduplication_no_duplicate_open_alert(db_session):
    """Calling generate_project_alerts twice for the same stale camera must
    not create a second open alert."""
    db = db_session
    project = _make_project(db)
    _make_camera(db, project.id, name="Dedup-Cam", last_active=_now() - _STALE_DELTA)

    generate_project_alerts(project.id, db)
    generate_project_alerts(project.id, db)

    open_stale_alerts = db.scalars(
        select(Alert).where(
            Alert.project_id == project.id,
            Alert.alert_type == "CAMERA",
            Alert.severity == "MEDIUM",
            Alert.status == "OPEN",
        )
    ).all()

    assert len(open_stale_alerts) == 1, (
        f"Expected exactly 1 open stale alert after 2 calls, got {len(open_stale_alerts)}"
    )


# ---------------------------------------------------------------------------
# Test D — Notification is created for a stale alert
# ---------------------------------------------------------------------------

def test_D_notification_created_for_stale_alert(db_session):
    """A Notification row must be created for the stale-camera alert."""
    db = db_session
    project = _make_project(db)
    _make_camera(db, project.id, name="Notify-Cam", last_active=_now() - _STALE_DELTA)

    alerts = generate_project_alerts(project.id, db)

    stale_alerts = [a for a in alerts if "has not reported activity" in (a.message or "")]
    assert len(stale_alerts) == 1, "Precondition: expected 1 stale alert"

    alert = stale_alerts[0]
    notification = db.scalars(
        select(Notification).where(Notification.alert_id == alert.id)
    ).first()

    assert notification is not None, (
        f"Expected a Notification linked to alert {alert.id}, found none"
    )


# ---------------------------------------------------------------------------
# Test E — Audit log is created for a stale alert
# ---------------------------------------------------------------------------

def test_E_audit_log_created_for_stale_alert(db_session):
    """An AuditLog row with entity_type=ALERT, action=CREATED must be created
    for the stale-camera alert."""
    db = db_session
    project = _make_project(db)
    _make_camera(db, project.id, name="Audit-Cam", last_active=_now() - _STALE_DELTA)

    alerts = generate_project_alerts(project.id, db)

    stale_alerts = [a for a in alerts if "has not reported activity" in (a.message or "")]
    assert len(stale_alerts) == 1, "Precondition: expected 1 stale alert"

    alert = stale_alerts[0]
    audit_entry = db.scalars(
        select(AuditLog).where(
            AuditLog.entity_type == "ALERT",
            AuditLog.entity_id == alert.id,
            AuditLog.action == "CREATED",
        )
    ).first()

    assert audit_entry is not None, (
        f"Expected AuditLog(entity_type=ALERT, entity_id={alert.id}, action=CREATED), found none"
    )


# ---------------------------------------------------------------------------
# Test F — Multiple cameras are handled independently
# ---------------------------------------------------------------------------

def test_F_multiple_stale_cameras_each_get_alert(db_session):
    """Each stale camera should produce its own CAMERA alert (distinct by name)."""
    db = db_session
    project = _make_project(db)

    _make_camera(db, project.id, name="Stale-A", last_active=_now() - _STALE_DELTA)
    _make_camera(db, project.id, name="Stale-B", last_active=_now() - _STALE_DELTA)
    _make_camera(db, project.id, name="Fresh-C", last_active=_now() - _FRESH_DELTA)

    alerts = generate_project_alerts(project.id, db)

    stale_alerts = [a for a in alerts if "has not reported activity" in (a.message or "")]
    assert len(stale_alerts) == 2, (
        f"Expected 2 stale alerts (one per stale camera), got {len(stale_alerts)}"
    )

    names_in_messages = {a.message for a in stale_alerts}
    assert any("Stale-A" in m for m in names_in_messages), "Expected alert for Stale-A"
    assert any("Stale-B" in m for m in names_in_messages), "Expected alert for Stale-B"
    assert not any("Fresh-C" in m for m in names_in_messages), "Fresh-C should not be stale"


# ---------------------------------------------------------------------------
# Test G — NULL last_active → no stale alert
# ---------------------------------------------------------------------------

def test_G_null_last_active_no_stale_alert(db_session):
    """A camera with last_active=NULL (never activated via API) must NOT
    generate a stale alert regardless of its status field."""
    db = db_session
    project = _make_project(db)
    # Camera is ACTIVE in status but has never had last_active set
    _make_camera(db, project.id, name="Null-Active-Cam", status="ACTIVE", last_active=None)

    alerts = generate_project_alerts(project.id, db)

    stale_alerts = [a for a in alerts if "has not reported activity" in (a.message or "")]
    assert stale_alerts == [], (
        "NULL last_active must not generate a stale alert; "
        f"unexpected alerts: {[a.message for a in stale_alerts]}"
    )


# ---------------------------------------------------------------------------
# Test H — Existing <75% / <50% ACTIVE camera availability alerts still fire
# ---------------------------------------------------------------------------

def test_H_existing_availability_alerts_still_fire(db_session):
    """The existing _camera_alert_for_project logic must be unaffected by
    Task 20 changes.

    Scenario: 1 project camera, status=INACTIVE → 0% availability → CRITICAL alert.
    """
    db = db_session
    project = _make_project(db)
    # Single camera that is INACTIVE → 0 / 1 = 0% < 50% → CRITICAL
    _make_camera(db, project.id, name="Offline-Cam", status="INACTIVE", last_active=None)

    alerts = generate_project_alerts(project.id, db)

    availability_alerts = [
        a for a in alerts
        if a.alert_type == "CAMERA" and "% of project cameras" in (a.message or "")
    ]
    assert len(availability_alerts) >= 1, (
        "Expected at least one existing availability alert for 0% ACTIVE cameras"
    )
    critical = [a for a in availability_alerts if a.severity == "CRITICAL"]
    assert len(critical) == 1, (
        f"Expected 1 CRITICAL availability alert, got {len(critical)}: "
        f"{[a.message for a in availability_alerts]}"
    )

