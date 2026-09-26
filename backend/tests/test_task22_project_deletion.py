"""
tests/test_task22_project_deletion.py — Task 22: Project Deletion & DB Cascade Hardening Tests

Covers:
1. Empty project deletion:
   - HTTP 200, existing success response, project deleted
2. Nonexistent project deletion:
   - HTTP 404, detail="Project not found"
3. Project with Camera dependency:
   - HTTP 409, detail="Project cannot be deleted while dependent records exist", project & camera preserved
4. Project with Media dependency:
   - HTTP 409, detail="Project cannot be deleted while dependent records exist", project & media preserved
5. Project with Inspection dependency:
   - HTTP 409, detail="Project cannot be deleted while dependent records exist", project & inspection preserved
6. Project with Alert dependency:
   - HTTP 409, detail="Project cannot be deleted while dependent records exist", project & alert preserved
7. Project with Attendance dependency:
   - HTTP 409, detail="Project cannot be deleted while dependent records exist", project & attendance preserved
8. Project with AI Detection dependency:
   - HTTP 409, detail="Project cannot be deleted while dependent records exist", project & ai_detection preserved
9. Project with Notification dependency:
   - HTTP 409, detail="Project cannot be deleted while dependent records exist", project & notification preserved
10. Project with Report dependency:
    - HTTP 409, detail="Project cannot be deleted while dependent records exist", project & report preserved
11. Project with VideoSession dependency:
    - HTTP 409, detail="Project cannot be deleted while dependent records exist", project & video_session preserved
12. Database commit failure:
    - Simulate SQLAlchemyError during commit on deletion
    - HTTP 500, detail="Failed to delete project", rollback invoked, project preserved

Uses isolated FastAPI test fixture pattern to avoid the known ReportEvidenceReference mapper issue.
"""

from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import patch
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.models.ai_detection import AIDetection
from app.models.alert import Alert
from app.models.attendance import Attendance
from app.models.camera import Camera
from app.models.inspection import Inspection
from app.models.media import Media
from app.models.notification import Notification
from app.models.project import Project
from app.models.report import Report
from app.models.video_session import VideoSession
from app.routers.projects import router as projects_router


def create_test_app() -> FastAPI:
    """Minimal FastAPI test app excluding unreferenced ReportEvidenceReference mapper."""
    app = FastAPI(title="DoSJE Test App - Task 22 Project Deletion Hardening")
    app.include_router(projects_router)
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

def make_project(session: Session, name: str = "Project 22", progress: Decimal = Decimal("10")) -> Project:
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


def make_camera(session: Session, project_id: int, name: str = "Camera 01") -> Camera:
    camera = Camera(
        project_id=project_id,
        camera_name=name,
        status="ACTIVE",
    )
    session.add(camera)
    session.commit()
    session.refresh(camera)
    return camera


def make_media(session: Session, project_id: int) -> Media:
    media = Media(
        project_id=project_id,
        media_type="IMAGE",
        source_type="UPLOAD",
        storage_provider="cloudinary",
        storage_public_id=f"media/{uuid4().hex}",
        media_url="https://res.cloudinary.com/demo/image/upload/sample.jpg",
    )
    session.add(media)
    session.commit()
    session.refresh(media)
    return media


def make_inspection(session: Session, project_id: int) -> Inspection:
    inspection = Inspection(
        project_id=project_id,
        inspection_type="MANUAL",
        status="PENDING",
        assignment_status="UNASSIGNED",
    )
    session.add(inspection)
    session.commit()
    session.refresh(inspection)
    return inspection


def make_alert(session: Session, project_id: int) -> Alert:
    alert = Alert(
        project_id=project_id,
        alert_type="RISK",
        severity="HIGH",
        message="High risk detected",
        status="OPEN",
    )
    session.add(alert)
    session.commit()
    session.refresh(alert)
    return alert


def make_attendance(session: Session, project_id: int) -> Attendance:
    attendance = Attendance(
        project_id=project_id,
        expected_workers=25,
    )
    session.add(attendance)
    session.commit()
    session.refresh(attendance)
    return attendance


def make_ai_detection(session: Session, project_id: int, camera_id: int) -> AIDetection:
    detection = AIDetection(
        project_id=project_id,
        camera_id=camera_id,
        people_detected=5,
        activity="working",
        confidence=Decimal("0.9500"),
        timestamp=datetime.now(timezone.utc),
    )
    session.add(detection)
    session.commit()
    session.refresh(detection)
    return detection


def make_notification(session: Session, project_id: int) -> Notification:
    notification = Notification(
        project_id=project_id,
        notification_type="SYSTEM",
        message="System notification",
        source="system",
        is_read=False,
    )
    session.add(notification)
    session.commit()
    session.refresh(notification)
    return notification


def make_report(session: Session, project_id: int, inspection_id: int) -> Report:
    report = Report(
        project_id=project_id,
        inspection_id=inspection_id,
        report_type="INSPECTION",
        status="DRAFT",
        title="Test Report",
    )
    session.add(report)
    session.commit()
    session.refresh(report)
    return report


def make_video_session(session: Session, project_id: int) -> VideoSession:
    video_session = VideoSession(
        project_id=project_id,
        session_id=f"sess-{uuid4().hex[:12]}",
        status="CREATED",
    )
    session.add(video_session)
    session.commit()
    session.refresh(video_session)
    return video_session


# ---------------------------------------------------------------------------
# Test Cases
# ---------------------------------------------------------------------------

def test_empty_project_deletion_success(client_and_db):
    """Test 1: Empty project with no dependencies is successfully deleted."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db, name="Standalone Project")
        project_id = project.id

    response = client.delete(f"/projects/{project_id}")
    assert response.status_code == 200
    assert response.json() == {"message": "Project deleted successfully"}

    with session_factory() as db:
        assert db.get(Project, project_id) is None


def test_nonexistent_project_deletion_404(client_and_db):
    """Test 2: Deleting a nonexistent project returns 404."""
    client, _ = client_and_db
    response = client.delete("/projects/999999")
    assert response.status_code == 404
    assert response.json()["detail"] == "Project not found"


def test_project_with_camera_blocks_deletion(client_and_db):
    """Test 3: Project with Camera dependency returns 409 and preserves records."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db)
        camera = make_camera(db, project.id)
        project_id = project.id
        camera_id = camera.id

    response = client.delete(f"/projects/{project_id}")
    assert response.status_code == 409
    assert response.json()["detail"] == "Project cannot be deleted while dependent records exist"

    with session_factory() as db:
        assert db.get(Project, project_id) is not None
        assert db.get(Camera, camera_id) is not None


def test_project_with_media_blocks_deletion(client_and_db):
    """Test 4: Project with Media dependency returns 409 and preserves records."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db)
        media = make_media(db, project.id)
        project_id = project.id
        media_id = media.id

    response = client.delete(f"/projects/{project_id}")
    assert response.status_code == 409
    assert response.json()["detail"] == "Project cannot be deleted while dependent records exist"

    with session_factory() as db:
        assert db.get(Project, project_id) is not None
        assert db.get(Media, media_id) is not None


def test_project_with_inspection_blocks_deletion(client_and_db):
    """Test 5: Project with Inspection dependency returns 409 and preserves records."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db)
        inspection = make_inspection(db, project.id)
        project_id = project.id
        inspection_id = inspection.id

    response = client.delete(f"/projects/{project_id}")
    assert response.status_code == 409
    assert response.json()["detail"] == "Project cannot be deleted while dependent records exist"

    with session_factory() as db:
        assert db.get(Project, project_id) is not None
        assert db.get(Inspection, inspection_id) is not None


def test_project_with_alert_blocks_deletion(client_and_db):
    """Test 6: Project with Alert dependency returns 409 and preserves records."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db)
        alert = make_alert(db, project.id)
        project_id = project.id
        alert_id = alert.id

    response = client.delete(f"/projects/{project_id}")
    assert response.status_code == 409
    assert response.json()["detail"] == "Project cannot be deleted while dependent records exist"

    with session_factory() as db:
        assert db.get(Project, project_id) is not None
        assert db.get(Alert, alert_id) is not None


def test_project_with_attendance_blocks_deletion(client_and_db):
    """Test 7: Project with Attendance dependency returns 409 and preserves records."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db)
        attendance = make_attendance(db, project.id)
        project_id = project.id
        attendance_id = attendance.id

    response = client.delete(f"/projects/{project_id}")
    assert response.status_code == 409
    assert response.json()["detail"] == "Project cannot be deleted while dependent records exist"

    with session_factory() as db:
        assert db.get(Project, project_id) is not None
        assert db.get(Attendance, attendance_id) is not None


def test_project_with_ai_detection_blocks_deletion(client_and_db):
    """Test 8: Project with AI Detection dependency returns 409 and preserves records."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db)
        camera = make_camera(db, project.id)
        detection = make_ai_detection(db, project.id, camera.id)
        project_id = project.id
        detection_id = detection.id

    response = client.delete(f"/projects/{project_id}")
    assert response.status_code == 409
    assert response.json()["detail"] == "Project cannot be deleted while dependent records exist"

    with session_factory() as db:
        assert db.get(Project, project_id) is not None
        assert db.get(AIDetection, detection_id) is not None


def test_project_with_notification_blocks_deletion(client_and_db):
    """Test 9: Project with Notification dependency returns 409 and preserves records."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db)
        notification = make_notification(db, project.id)
        project_id = project.id
        notification_id = notification.id

    response = client.delete(f"/projects/{project_id}")
    assert response.status_code == 409
    assert response.json()["detail"] == "Project cannot be deleted while dependent records exist"

    with session_factory() as db:
        assert db.get(Project, project_id) is not None
        assert db.get(Notification, notification_id) is not None


def test_project_with_report_blocks_deletion(client_and_db):
    """Test 10: Project with Report dependency returns 409 and preserves records."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db)
        inspection = make_inspection(db, project.id)
        report = make_report(db, project.id, inspection.id)
        project_id = project.id
        report_id = report.id

    response = client.delete(f"/projects/{project_id}")
    assert response.status_code == 409
    assert response.json()["detail"] == "Project cannot be deleted while dependent records exist"

    with session_factory() as db:
        assert db.get(Project, project_id) is not None
        assert db.get(Report, report_id) is not None


def test_project_with_video_session_blocks_deletion(client_and_db):
    """Test 11: Project with VideoSession dependency returns 409 and preserves records."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db)
        session_rec = make_video_session(db, project.id)
        project_id = project.id
        video_session_id = session_rec.id

    response = client.delete(f"/projects/{project_id}")
    assert response.status_code == 409
    assert response.json()["detail"] == "Project cannot be deleted while dependent records exist"

    with session_factory() as db:
        assert db.get(Project, project_id) is not None
        assert db.get(VideoSession, video_session_id) is not None


def test_project_deletion_commit_failure_raises_500(client_and_db):
    """Test 12: DB commit failure raises HTTP 500, rolls back, and does not delete project."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db, name="Commit Failure Test")
        project_id = project.id

    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated DB commit error")):
        response = client.delete(f"/projects/{project_id}")

    assert response.status_code == 500
    assert response.json()["detail"] == "Failed to delete project"
    # Ensure raw database exception text is not exposed
    assert "Simulated DB commit error" not in response.text

    # Verify project still exists in DB because of rollback
    with session_factory() as db:
        assert db.get(Project, project_id) is not None
