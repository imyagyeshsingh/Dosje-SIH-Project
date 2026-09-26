"""
tests/test_task21b_hardening.py — Task 21B: Concurrency & Database Error Hardening Tests

Covers:
1. Alert behavior:
   - OPEN alert deduplication blocks duplicate generation
   - RESOLVED/ACKNOWLEDGED lifecycle permits later OPEN alert
   - generate_project_alerts() query retains row locking (with_for_update)
   - direct alert creation and status update DB error hardening (rollback + 500)
2. Notification behavior:
   - dedupe=True blocks duplicate
   - dedupe=False persists duplicate
   - mark-single-read DB failure produces controlled 500 + rollback
   - mark-all-read DB failure produces controlled 500 + rollback
3. AI detection:
   - DB commit failure produces controlled 500 + rollback
4. Inspection DB failure hardening:
   - location submission DB failure produces controlled 500 + rollback
   - manual assignment DB failure produces controlled 500 + rollback
   - random assignment DB failure produces controlled 500 + rollback
   - status transition DB failure produces controlled 500 + rollback
   - general update DB failure produces controlled 500 + rollback
   - video-session creation/linking DB failure produces controlled 500 + rollback
5. VideoSession DB failure hardening:
   - update DB failure produces controlled 500 + rollback
   - start DB failure produces controlled 500 + rollback
   - end DB failure produces controlled 500 + rollback
   - cancel DB failure produces controlled 500 + rollback
   - inspection linkage DB failure produces controlled 500 + rollback
6. Startup DB logging:
   - SQLAlchemy startup errors are logged via logger.exception

Uses isolated FastAPI test fixture pattern to avoid the known ReportEvidenceReference mapper issue.
"""

import inspect
import logging
from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.models.ai_detection import AIDetection
from app.models.alert import Alert
from app.models.camera import Camera
from app.models.inspection import Inspection
from app.models.inspector import Inspector
from app.models.notification import Notification
from app.models.project import Project
from app.models.video_session import VideoSession
from app.routers.ai import router as ai_router
from app.routers.alerts import router as alerts_router
from app.routers.cctv import router as cctv_router
from app.routers.inspections import router as inspections_router
from app.routers.inspectors import router as inspectors_router
from app.routers.notifications import router as notifications_router
from app.routers.projects import router as projects_router
from app.routers.video_sessions import router as video_sessions_router
from app.services.alert_service import generate_project_alerts
from app.services.notification_service import create_notification


def create_test_app() -> FastAPI:
    """Minimal FastAPI test app excluding the unreferenced ReportEvidenceReference mapper."""
    app = FastAPI(title="DoSJE Test App - Task 21B Hardening")
    app.include_router(projects_router)
    app.include_router(cctv_router)
    app.include_router(inspectors_router)
    app.include_router(inspections_router)
    app.include_router(alerts_router)
    app.include_router(notifications_router)
    app.include_router(video_sessions_router)
    app.include_router(ai_router)
    return app


@pytest.fixture
def client_and_db():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    Base.metadata.create_all(bind=engine)

    app = create_test_app()

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


# ---------------------------------------------------------------------------
# Helper model factories
# ---------------------------------------------------------------------------

def make_project(session: Session, name: str = "Project 21B", progress: Decimal = Decimal("10")) -> Project:
    project = Project(
        project_name=name,
        project_code=f"PRJ-{uuid4().hex[:8].upper()}",
        status="ACTIVE",
        progress=progress,
        latitude=Decimal("28.6139"),
        longitude=Decimal("77.2090"),
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def make_inspector(session: Session, inspector_id: str = "INS-21B", name: str = "Officer Test") -> Inspector:
    inspector = Inspector(
        inspector_id=inspector_id,
        inspector_name=name,
        is_active=True,
    )
    session.add(inspector)
    session.commit()
    session.refresh(inspector)
    return inspector


def make_camera(session: Session, project_id: int, status: str = "ACTIVE") -> Camera:
    camera = Camera(
        project_id=project_id,
        camera_name=f"CAM-{uuid4().hex[:6]}",
        stream_url=f"rtsp://example.com/live/{uuid4().hex[:6]}",
        status=status,
    )
    session.add(camera)
    session.commit()
    session.refresh(camera)
    return camera


def make_inspection(session: Session, project_id: int, status: str = "PENDING") -> Inspection:
    inspection = Inspection(
        project_id=project_id,
        inspection_type="MANUAL",
        status=status,
    )
    session.add(inspection)
    session.commit()
    session.refresh(inspection)
    return inspection


def make_video_session(session: Session, project_id: int, inspection_id: int | None = None) -> VideoSession:
    vs = VideoSession(
        project_id=project_id,
        inspection_id=inspection_id,
        session_id=str(uuid4()),
        status="CREATED",
    )
    session.add(vs)
    session.commit()
    session.refresh(vs)
    return vs


# ===========================================================================
# 1. Alert behavior & Concurrency / Row-Locking Tests
# ===========================================================================

def test_alert_open_duplicate_blocked(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        # Progress 10 -> high risk -> generates RISK alert
        project = make_project(session, progress=Decimal("10"))
        project_id = project.id

    # First generation creates alert
    resp1 = client.post(f"/alerts/generate/{project_id}")
    assert resp1.status_code == 200
    alerts1 = resp1.json()
    assert len(alerts1) > 0

    # Second generation should NOT duplicate existing OPEN alerts
    resp2 = client.post(f"/alerts/generate/{project_id}")
    assert resp2.status_code == 200
    alerts2 = resp2.json()
    assert len(alerts2) == 0


def test_alert_resolved_allows_new_open_alert(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session, progress=Decimal("10"))
        project_id = project.id

    resp1 = client.post(f"/alerts/generate/{project_id}")
    assert resp1.status_code == 200
    created_alert = resp1.json()[0]

    # Resolve the alert
    patch_resp = client.put(f"/alerts/{created_alert['id']}/status", json={"status": "RESOLVED"})
    assert patch_resp.status_code == 200
    assert patch_resp.json()["status"] == "RESOLVED"

    # Now generating alerts again should permit a new OPEN alert since the previous is RESOLVED
    resp2 = client.post(f"/alerts/generate/{project_id}")
    assert resp2.status_code == 200
    new_alerts = resp2.json()
    assert len(new_alerts) > 0
    assert any(a["status"] == "OPEN" and a["alert_type"] == created_alert["alert_type"] for a in new_alerts)


def test_alert_acknowledged_allows_new_open_alert(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session, progress=Decimal("10"))
        project_id = project.id

    resp1 = client.post(f"/alerts/generate/{project_id}")
    assert resp1.status_code == 200
    created_alert = resp1.json()[0]

    # Acknowledge the alert
    patch_resp = client.put(f"/alerts/{created_alert['id']}/status", json={"status": "ACKNOWLEDGED"})
    assert patch_resp.status_code == 200
    assert patch_resp.json()["status"] == "ACKNOWLEDGED"

    # Regenerating should create a new OPEN alert
    resp2 = client.post(f"/alerts/generate/{project_id}")
    assert resp2.status_code == 200
    new_alerts = resp2.json()
    assert len(new_alerts) > 0
    assert any(a["status"] == "OPEN" for a in new_alerts)


def test_generate_project_alerts_retains_row_locking_query():
    """Verify that generate_project_alerts inspects/locks Project row via with_for_update."""
    source_code = inspect.getsource(generate_project_alerts)
    assert "with_for_update()" in source_code
    assert "select(Project)" in source_code


def test_create_alert_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        project_id = project.id

    payload = {
        "project_id": project_id,
        "alert_type": "RISK",
        "severity": "HIGH",
        "message": "Manual risk alert test",
    }

    rollback_called = False
    original_rollback = Session.rollback

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated DB write failure")), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.post("/alerts", json=payload)
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to save alert"
        assert rollback_called


def test_update_alert_status_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        alert = Alert(
            project_id=project.id,
            alert_type="RISK",
            severity="MEDIUM",
            message="Test alert",
            status="OPEN",
        )
        session.add(alert)
        session.commit()
        session.refresh(alert)
        alert_id = alert.id

    rollback_called = False
    original_rollback = Session.rollback

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated DB update failure")), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.put(f"/alerts/{alert_id}/status", json={"status": "RESOLVED"})
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to update alert status"
        assert rollback_called


# ===========================================================================
# 2. Notification Behavior & Error Hardening Tests
# ===========================================================================

def test_notification_dedupe_true_and_false_behavior(client_and_db):
    _, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        project_id = project.id

        # dedupe=True: First insert succeeds, second returns None
        n1 = create_notification(
            db=session,
            project_id=project_id,
            notification_type="SYSTEM",
            message="Deduped test message",
            source="TEST",
            dedupe=True,
        )
        assert n1 is not None

        n2 = create_notification(
            db=session,
            project_id=project_id,
            notification_type="SYSTEM",
            message="Deduped test message",
            source="TEST",
            dedupe=True,
        )
        assert n2 is None

        # dedupe=False: creates duplicate successfully
        n3 = create_notification(
            db=session,
            project_id=project_id,
            notification_type="SYSTEM",
            message="Deduped test message",
            source="TEST",
            dedupe=False,
        )
        assert n3 is not None
        assert n3.id != n1.id


def test_notification_mark_single_read_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        notif = Notification(
            project_id=project.id,
            notification_type="SYSTEM",
            message="Mark read test",
            source="TEST",
            is_read=False,
        )
        session.add(notif)
        session.commit()
        session.refresh(notif)
        notif_id = notif.id

    rollback_called = False
    original_rollback = Session.rollback

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated DB failure")), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.put(f"/notifications/{notif_id}/read")
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to mark notification as read"
        assert rollback_called


def test_notification_mark_all_read_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        notif = Notification(
            project_id=project.id,
            notification_type="SYSTEM",
            message="Bulk read test",
            source="TEST",
            is_read=False,
        )
        session.add(notif)
        session.commit()

    rollback_called = False
    original_rollback = Session.rollback

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated DB failure")), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.put("/notifications/read-all")
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to mark notifications as read"
        assert rollback_called


# ===========================================================================
# 3. AI Detection DB Error Hardening Tests
# ===========================================================================

def test_ai_detection_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        camera = make_camera(session, project.id)
        project_id = project.id
        camera_id = camera.id

    payload = {
        "project_id": project_id,
        "camera_id": camera_id,
        "people_detected": 10,
        "activity": "NORMAL",
        "confidence": 0.95,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    rollback_called = False
    original_rollback = Session.rollback

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated AI detection DB failure")), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.post("/ai/detection", json=payload)
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to save AI detection"
        assert rollback_called


# ===========================================================================
# 4. Inspection DB Error Hardening Tests
# ===========================================================================

def test_inspection_location_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        inspection = make_inspection(session, project.id)
        inspection_id = inspection.id

    payload = {
        "latitude": 28.6140,
        "longitude": 77.2091,
        "location_accuracy": 5.0,
    }

    rollback_called = False
    original_rollback = Session.rollback

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated location DB failure")), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.post(f"/inspections/{inspection_id}/location", json=payload)
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to save inspection location"
        assert rollback_called


def test_inspection_assign_inspector_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        inspector = make_inspector(session)
        inspection = make_inspection(session, project.id)
        inspection_id = inspection.id
        inspector_id = inspector.inspector_id

    payload = {
        "inspector_id": inspector_id,
        "inspector_name": "Officer Test",
        "assignment_status": "ASSIGNED",
    }

    rollback_called = False
    original_rollback = Session.rollback

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated assignment DB failure")), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.post(f"/inspections/{inspection_id}/assign", json=payload)
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to assign inspector to inspection"
        assert rollback_called


def test_inspection_assign_random_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        make_inspector(session)
        inspection = make_inspection(session, project.id)
        inspection_id = inspection.id

    rollback_called = False
    original_rollback = Session.rollback

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated random assignment DB failure")), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.post(f"/inspections/{inspection_id}/assign-random")
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to assign random inspector to inspection"
        assert rollback_called


def test_inspection_update_status_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        inspection = make_inspection(session, project.id, status="PENDING")
        inspection_id = inspection.id

    rollback_called = False
    original_rollback = Session.rollback

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated status transition DB failure")), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.put(f"/inspections/{inspection_id}/status", json={"status": "SCHEDULED"})
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to update inspection status"
        assert rollback_called


def test_inspection_update_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        inspection = make_inspection(session, project.id, status="PENDING")
        inspection_id = inspection.id

    rollback_called = False
    original_rollback = Session.rollback

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated update DB failure")), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.put(f"/inspections/{inspection_id}", json={"reason": "Updated inspection reason"})
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to update inspection"
        assert rollback_called


def test_inspection_video_session_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        inspection = make_inspection(session, project.id)
        inspection_id = inspection.id

    rollback_called = False
    original_rollback = Session.rollback

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated video session creation DB failure")), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.post(f"/inspections/{inspection_id}/video-session")
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to save video session for inspection"
        assert rollback_called


# ===========================================================================
# 5. VideoSession DB Error Hardening Tests
# ===========================================================================

def test_video_session_update_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        vs = make_video_session(session, project.id)
        session_id = vs.id

    rollback_called = False
    original_rollback = Session.rollback

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated VS update DB failure")), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.put(f"/video-sessions/{session_id}", json={"officer_name": "Updated Officer"})
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to update video session"
        assert rollback_called


def test_video_session_start_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        vs = make_video_session(session, project.id)
        session_id = vs.id

    rollback_called = False
    original_rollback = Session.rollback

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated VS start DB failure")), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.post(f"/video-sessions/{session_id}/start")
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to start video session"
        assert rollback_called


def test_video_session_end_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        vs = make_video_session(session, project.id)
        vs.status = "ACTIVE"
        session.commit()
        session_id = vs.id

    rollback_called = False
    original_rollback = Session.rollback

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated VS end DB failure")), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.post(f"/video-sessions/{session_id}/end")
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to end video session"
        assert rollback_called


def test_video_session_cancel_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        vs = make_video_session(session, project.id)
        session_id = vs.id

    rollback_called = False
    original_rollback = Session.rollback

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated VS cancel DB failure")), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.post(f"/video-sessions/{session_id}/cancel")
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to cancel video session"
        assert rollback_called


def test_video_session_inspection_link_db_failure_returns_controlled_500(client_and_db):
    client, SessionLocal = client_and_db
    with SessionLocal() as session:
        project = make_project(session)
        inspection = make_inspection(session, project.id)
        project_id = project.id
        inspection_id = inspection.id

    payload = {
        "project_id": project_id,
        "inspection_id": inspection_id,
        "officer_name": "Officer Test",
    }

    call_count = 0
    original_commit = Session.commit
    rollback_called = False
    original_rollback = Session.rollback

    def mock_commit(self):
        nonlocal call_count
        call_count += 1
        # Let the session record commit succeed (call 1), but fail on inspection linkage (call 2)
        if call_count > 1:
            raise SQLAlchemyError("Simulated linkage failure")
        return original_commit(self)

    def tracking_rollback(self):
        nonlocal rollback_called
        rollback_called = True
        original_rollback(self)

    with patch.object(Session, "commit", side_effect=mock_commit, autospec=True), \
         patch.object(Session, "rollback", side_effect=tracking_rollback, autospec=True):
        resp = client.post("/video-sessions", json=payload)
        assert resp.status_code == 500
        assert resp.json()["detail"] == "Failed to link video session to inspection"
        assert rollback_called


# ===========================================================================
# 6. Startup Database Logging Test
# ===========================================================================

def test_startup_database_tables_logs_exception():
    """Verify in an isolated subprocess that app.main.create_database_tables logs an exception when metadata creation fails."""
    import subprocess
    import sys

    sub_code = """
import logging
from unittest.mock import patch
from sqlalchemy.exc import SQLAlchemyError
import app.main

with patch("app.main.Base.metadata.create_all", side_effect=SQLAlchemyError("Connection refused")), \
     patch.object(app.main.logger, "exception") as mock_log:
    app.main.create_database_tables()
    assert mock_log.called
    assert "Failed to create database tables during startup" in str(mock_log.call_args)
print("STARTUP_LOGGING_OK")
"""
    result = subprocess.run([sys.executable, "-c", sub_code], capture_output=True, text=True)
    assert result.returncode == 0, f"Startup logging test failed: {result.stderr}"
    assert "STARTUP_LOGGING_OK" in result.stdout
