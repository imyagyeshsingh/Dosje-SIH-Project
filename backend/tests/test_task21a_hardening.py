"""
tests/test_task21a_hardening.py — Task 21A: API Hardening, Relationship Validation & Whitespace Checks

Tests covering:
1. Inspection creation with nonexistent alert (404)
2. Inspection creation with cross-project alert (400)
3. Inspection update with cross-project alert (400)
4. Inspection update with nonexistent alert (404)
5. Inspection update project change with existing alert mismatch (400)
6. Manual assignment with nonexistent inspector (404)
7. Manual assignment with existing inspector (200)
8. Inspection creation with nonexistent officer_id (404)
9. Inspection update with nonexistent officer_id (404)
10. Project creation with whitespace-only name (422)
11. Project creation with whitespace-only code (422)
12. Project creation strips leading/trailing whitespace (201)
13. Camera creation with whitespace-only name (422)
14. Camera update with whitespace-only name (422)
15. Camera creation with malformed stream URL (422)
16. Camera update with malformed stream URL (422)
17. Camera creation with stream URL containing spaces (422)
18. Camera creation with malformed video path containing spaces (422)
19. Camera update with malformed video path (422)
20. Camera creation with valid storage video path (201)
21. Report title whitespace validation (ReportCreate & ReportUpdate reject whitespace-only with 422)
22. Media URL validation (MediaCreate rejects blank, malformed, spaced URLs; accepts valid http/https)

Uses the isolated FastAPI test fixture pattern from test_ai_api.py / test_camera_health.py
to avoid the pre-existing Task 18 ReportEvidenceReference mapper conflict (Deferred Issue 1).
"""

from datetime import datetime, timezone
from decimal import Decimal
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.models.alert import Alert
from app.models.audit_log import AuditLog
from app.models.camera import Camera
from app.models.inspection import Inspection
from app.models.inspector import Inspector
from app.models.media import Media
from app.models.notification import Notification
from app.models.project import Project
from app.models.video_session import VideoSession
from app.routers.alerts import router as alerts_router
from app.routers.cctv import router as cctv_router
from app.routers.inspections import router as inspections_router
from app.routers.inspectors import router as inspectors_router
from app.routers.projects import router as projects_router
from app.schemas.camera import CameraCreate, CameraUpdate
from app.schemas.media import MediaCreate
from app.schemas.report import ReportCreate, ReportUpdate


def create_test_app() -> FastAPI:
    """Minimal FastAPI test application excluding ReportEvidenceReference mapper."""
    app = FastAPI(title="DoSJE Test App - Task 21A Hardening")
    app.include_router(projects_router)
    app.include_router(cctv_router)
    app.include_router(inspectors_router)
    app.include_router(inspections_router)
    app.include_router(alerts_router)
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


def create_project(session: Session, project_name: str = "Project 21A") -> Project:
    project = Project(
        project_name=project_name,
        project_code=f"PRJ-{uuid4().hex[:8].upper()}",
        status="ACTIVE",
        progress=Decimal("50"),
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def create_inspector(session: Session, inspector_id: str = "INS-001", name: str = "Officer Smith") -> Inspector:
    inspector = Inspector(
        inspector_id=inspector_id,
        inspector_name=name,
        is_active=True,
    )
    session.add(inspector)
    session.commit()
    session.refresh(inspector)
    return inspector


def create_alert(session: Session, project_id: int, message: str = "Test alert") -> Alert:
    alert = Alert(
        project_id=project_id,
        alert_type="RISK",
        severity="HIGH",
        message=message,
        status="OPEN",
        source="RISK_ENGINE",
    )
    session.add(alert)
    session.commit()
    session.refresh(alert)
    return alert


# ===========================================================================
# 1. 21A-1: Inspection Alert Relationship Validation
# ===========================================================================

def test_create_inspection_with_nonexistent_alert_returns_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/inspections",
            json={
                "project_id": project.id,
                "inspection_type": "MANUAL",
                "status": "PENDING",
                "alert_id": 99999,
            },
        )
        assert response.status_code == 404
        assert "Alert not found" in response.json()["detail"]
    finally:
        db.close()


def test_create_inspection_with_cross_project_alert_returns_400(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")
        other_alert = create_alert(db, project_b.id, "Alert on Project B")

        response = client.post(
            "/inspections",
            json={
                "project_id": project_a.id,
                "inspection_type": "MANUAL",
                "status": "PENDING",
                "alert_id": other_alert.id,
            },
        )
        assert response.status_code == 400
        assert "Alert does not belong to the specified project" in response.json()["detail"]
    finally:
        db.close()


def test_update_inspection_with_cross_project_alert_returns_400(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")
        other_alert = create_alert(db, project_b.id, "Alert on Project B")

        inspection = Inspection(
            project_id=project_a.id,
            inspection_type="MANUAL",
            status="PENDING",
        )
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.put(
            f"/inspections/{inspection.id}",
            json={"alert_id": other_alert.id},
        )
        assert response.status_code == 400
        assert "Alert does not belong to the specified project" in response.json()["detail"]
    finally:
        db.close()


def test_update_inspection_with_nonexistent_alert_returns_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(
            project_id=project.id,
            inspection_type="MANUAL",
            status="PENDING",
        )
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.put(
            f"/inspections/{inspection.id}",
            json={"alert_id": 88888},
        )
        assert response.status_code == 404
        assert "Alert not found" in response.json()["detail"]
    finally:
        db.close()


def test_update_inspection_project_mismatch_with_existing_alert_returns_400(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")
        alert_a = create_alert(db, project_a.id, "Alert for A")

        inspection = Inspection(
            project_id=project_a.id,
            alert_id=alert_a.id,
            inspection_type="ALERT_TRIGGERED",
            status="PENDING",
        )
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        # Attempt to reassign inspection to Project B without updating alert_id
        response = client.put(
            f"/inspections/{inspection.id}",
            json={"project_id": project_b.id},
        )
        assert response.status_code == 400
        assert "Alert does not belong to the specified project" in response.json()["detail"]
    finally:
        db.close()


# ===========================================================================
# 2. 21A-2: Manual Inspector Assignment & Creation Validation
# ===========================================================================

def test_manual_assignment_with_nonexistent_inspector_returns_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(
            project_id=project.id,
            inspection_type="MANUAL",
            status="PENDING",
        )
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.post(
            f"/inspections/{inspection.id}/assign",
            json={
                "inspector_id": "GHOST-INSPECTOR-99",
                "inspector_name": "Ghost",
            },
        )
        assert response.status_code == 404
        assert "Inspector not found" in response.json()["detail"]
    finally:
        db.close()


def test_manual_assignment_with_existing_inspector_succeeds(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspector = create_inspector(db, inspector_id="INS-VALID-1", name="Real Inspector")
        inspection = Inspection(
            project_id=project.id,
            inspection_type="MANUAL",
            status="PENDING",
        )
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.post(
            f"/inspections/{inspection.id}/assign",
            json={
                "inspector_id": inspector.inspector_id,
                "inspector_name": inspector.inspector_name,
            },
        )
        assert response.status_code == 200
        assert response.json()["officer_id"] == inspector.inspector_id
        assert response.json()["assignment_status"] == "ASSIGNED"
    finally:
        db.close()


def test_create_inspection_with_nonexistent_officer_returns_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/inspections",
            json={
                "project_id": project.id,
                "inspection_type": "MANUAL",
                "status": "PENDING",
                "officer_id": "NO-SUCH-OFFICER",
            },
        )
        assert response.status_code == 404
        assert "Inspector not found" in response.json()["detail"]
    finally:
        db.close()


def test_update_inspection_with_nonexistent_officer_returns_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(
            project_id=project.id,
            inspection_type="MANUAL",
            status="PENDING",
        )
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.put(
            f"/inspections/{inspection.id}",
            json={"officer_id": "UNKNOWN-OFFICER"},
        )
        assert response.status_code == 404
        assert "Inspector not found" in response.json()["detail"]
    finally:
        db.close()


# ===========================================================================
# 3. 21A-3: Whitespace Validation
# ===========================================================================

def test_create_project_with_whitespace_only_name_returns_422(client_and_db):
    client, _ = client_and_db
    response = client.post(
        "/projects",
        json={
            "project_name": "    \t  \n  ",
            "project_code": "PRJ-WS-01",
            "status": "ACTIVE",
            "progress": 50,
        },
    )
    assert response.status_code == 422


def test_create_project_with_whitespace_only_code_returns_422(client_and_db):
    client, _ = client_and_db
    response = client.post(
        "/projects",
        json={
            "project_name": "Valid Name",
            "project_code": "    ",
            "status": "ACTIVE",
            "progress": 50,
        },
    )
    assert response.status_code == 422


def test_create_project_strips_leading_trailing_whitespace(client_and_db):
    client, _ = client_and_db
    response = client.post(
        "/projects",
        json={
            "project_name": "  Trimmed Project  ",
            "project_code": "  TRIM-CODE-01  ",
            "status": "ACTIVE",
            "progress": 50,
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["project_name"] == "Trimmed Project"
    assert data["project_code"] == "TRIM-CODE-01"


def test_create_camera_with_whitespace_only_name_returns_422(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/cctv",
            json={
                "project_id": project.id,
                "camera_name": "   \t   ",
                "stream_url": "rtsp://example.com/stream",
                "status": "ACTIVE",
            },
        )
        assert response.status_code == 422
    finally:
        db.close()


def test_camera_update_with_whitespace_only_name_returns_422():
    with pytest.raises(ValidationError):
        CameraUpdate(camera_name="   \t  ")


def test_report_title_whitespace_only_returns_422():
    with pytest.raises(ValidationError):
        ReportCreate(
            project_id=1,
            inspection_id=1,
            report_type="INSPECTION",
            title="   \t \n  ",
        )

    with pytest.raises(ValidationError):
        ReportUpdate(title="   ")


# ===========================================================================
# 4. 21A-4: Media / Source Validation
# ===========================================================================

def test_camera_create_with_malformed_stream_url_returns_422(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/cctv",
            json={
                "project_id": project.id,
                "camera_name": "Bad Stream Cam",
                "stream_url": "ftp://bad-scheme.com/stream",
                "status": "ACTIVE",
            },
        )
        assert response.status_code == 422
    finally:
        db.close()


def test_camera_update_with_malformed_stream_url_returns_422():
    with pytest.raises(ValidationError):
        CameraUpdate(stream_url="not-a-url")

    with pytest.raises(ValidationError):
        CameraUpdate(stream_url="rtsp://invalid url with spaces/stream")


def test_camera_create_with_stream_url_containing_spaces_returns_422(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/cctv",
            json={
                "project_id": project.id,
                "camera_name": "Spaced Cam",
                "stream_url": "rtsp://example com/stream",
                "status": "ACTIVE",
            },
        )
        assert response.status_code == 422
    finally:
        db.close()


def test_camera_create_with_malformed_video_path_returns_422(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/cctv",
            json={
                "project_id": project.id,
                "camera_name": "Bad Path Cam",
                "video_path": "C:/videos with spaces/file.mp4",
                "status": "ACTIVE",
            },
        )
        assert response.status_code == 422
    finally:
        db.close()


def test_camera_update_with_malformed_video_path_returns_422():
    with pytest.raises(ValidationError):
        CameraUpdate(video_path="  ")

    with pytest.raises(ValidationError):
        CameraUpdate(video_path="/path with spaces/video.mp4")


def test_camera_create_accepts_valid_storage_video_path(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/cctv",
            json={
                "project_id": project.id,
                "camera_name": "Storage Cam",
                "video_path": "/var/lib/storage/cctv/cam01.mp4",
                "status": "ACTIVE",
            },
        )
        assert response.status_code == 201
        assert response.json()["video_path"] == "/var/lib/storage/cctv/cam01.mp4"
    finally:
        db.close()


def test_media_create_url_validation():
    # Blank media_url rejected
    with pytest.raises(ValidationError):
        MediaCreate(
            project_id=1,
            media_type="IMAGE",
            source_type="UPLOAD",
            storage_provider="cloudinary",
            storage_public_id="pub-1",
            media_url="   ",
        )

    # Malformed URL without scheme rejected
    with pytest.raises(ValidationError):
        MediaCreate(
            project_id=1,
            media_type="IMAGE",
            source_type="UPLOAD",
            storage_provider="cloudinary",
            storage_public_id="pub-2",
            media_url="not-a-valid-url",
        )

    # URL with spaces rejected
    with pytest.raises(ValidationError):
        MediaCreate(
            project_id=1,
            media_type="IMAGE",
            source_type="UPLOAD",
            storage_provider="cloudinary",
            storage_public_id="pub-3",
            media_url="https://example com/media/file.jpg",
        )

    # Valid HTTP/HTTPS accepted
    media = MediaCreate(
        project_id=1,
        media_type="IMAGE",
        source_type="UPLOAD",
        storage_provider="cloudinary",
        storage_public_id="pub-4",
        media_url="https://res.cloudinary.com/demo/image/upload/sample.jpg",
    )
    assert media.media_url == "https://res.cloudinary.com/demo/image/upload/sample.jpg"
