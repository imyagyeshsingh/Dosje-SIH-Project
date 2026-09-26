from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.alert import Alert
from app.models.inspection import Inspection
from app.models.project import Project
from app.models.video_session import VideoSession


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


def create_project(session, project_name: str = "Project A") -> Project:
    project = Project(
        project_name=project_name,
        project_code=f"INT-{project_name.lower().replace(' ', '-')}-{datetime.now(timezone.utc).timestamp()}",
        status="ACTIVE",
        progress=50,
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def create_inspection(session, project_id: int, inspection_type: str = "MANUAL", status: str = "PENDING") -> Inspection:
    inspection = Inspection(
        project_id=project_id,
        inspection_type=inspection_type,
        status=status,
        officer_name="Officer A",
    )
    session.add(inspection)
    session.commit()
    session.refresh(inspection)
    return inspection


def make_alert(session, project_id: int) -> Alert:
    alert = Alert(
        project_id=project_id,
        alert_type="CAMERA",
        severity="HIGH",
        message="Camera disconnected",
        source="CAMERA_MONITOR",
        status="OPEN",
    )
    session.add(alert)
    session.commit()
    session.refresh(alert)
    return alert


def test_inspection_can_create_video_session(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)

        response = client.post(f"/inspections/{inspection.id}/video-session")

        assert response.status_code == 201
        data = response.json()
        assert data["inspection_id"] == inspection.id
        assert data["project_id"] == project.id
        assert data["status"] == "CREATED"
        assert data["session_id"]

        db.refresh(inspection)
        assert inspection.video_session_id == data["session_id"]

        session_count = db.query(VideoSession).filter(VideoSession.inspection_id == inspection.id).count()
        assert session_count == 1
    finally:
        db.close()


def test_inspection_video_session_lookup_returns_session(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)
        session = VideoSession(
            project_id=project.id,
            inspection_id=inspection.id,
            session_id="550e8400-e29b-41d4-a716-446655440100",
            status="CREATED",
        )
        db.add(session)
        db.commit()
        db.refresh(session)

        response = client.get(f"/inspections/{inspection.id}/video-session")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == session.id
        assert data["inspection_id"] == inspection.id
    finally:
        db.close()


def test_inspection_video_session_lookup_missing_or_invalid_returns_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)

        missing_response = client.get("/inspections/999/video-session")
        assert missing_response.status_code == 404

        empty_response = client.get(f"/inspections/{inspection.id}/video-session")
        assert empty_response.status_code == 404
    finally:
        db.close()


def test_inspection_video_session_creation_is_idempotent(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)

        first = client.post(f"/inspections/{inspection.id}/video-session")
        second = client.post(f"/inspections/{inspection.id}/video-session")

        assert first.status_code == 201
        assert second.status_code == 200
        assert first.json()["id"] == second.json()["id"]

        count = db.query(VideoSession).filter(VideoSession.inspection_id == inspection.id).count()
        assert count == 1
    finally:
        db.close()


def test_random_inspection_can_create_video_session(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id, inspection_type="RANDOM")

        response = client.post(f"/inspections/{inspection.id}/video-session")

        assert response.status_code == 201
        data = response.json()
        assert data["project_id"] == project.id
        assert data["inspection_id"] == inspection.id
    finally:
        db.close()


def test_alert_triggered_inspection_can_create_video_session_and_preserve_alert_status(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        alert = make_alert(db, project.id)

        inspection_response = client.post(f"/inspections/from-alert/{alert.id}")
        assert inspection_response.status_code == 201
        inspection_id = inspection_response.json()["id"]

        video_response = client.post(f"/inspections/{inspection_id}/video-session")
        assert video_response.status_code == 201
        assert video_response.json()["inspection_id"] == inspection_id

        db.refresh(alert)
        assert alert.status == "OPEN"
    finally:
        db.close()


def test_video_session_start_does_not_bypass_inspection_workflow(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)
        session_response = client.post(f"/inspections/{inspection.id}/video-session")
        session_id = session_response.json()["id"]

        start_response = client.post(f"/video-sessions/{session_id}/start")
        assert start_response.status_code == 200
        db.refresh(inspection)
        assert inspection.status == "PENDING"
    finally:
        db.close()


def test_video_session_end_does_not_complete_inspection(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id, status="IN_PROGRESS")
        session_response = client.post(f"/inspections/{inspection.id}/video-session")
        session_id = session_response.json()["id"]

        start_response = client.post(f"/video-sessions/{session_id}/start")
        assert start_response.status_code == 200

        end_response = client.post(f"/video-sessions/{session_id}/end")
        assert end_response.status_code == 200
        db.refresh(inspection)
        assert inspection.status == "IN_PROGRESS"
    finally:
        db.close()
