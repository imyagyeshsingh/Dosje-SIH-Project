from datetime import datetime, timezone
from uuid import UUID

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
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
        project_code=f"VS-{project_name.lower().replace(' ', '-')}-{datetime.now(timezone.utc).timestamp()}",
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


def test_video_session_model_and_schema_registration():
    assert VideoSession.__tablename__ == "video_sessions"
    assert "video_sessions" in Base.metadata.tables


def test_create_video_session_success(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        payload = {
            "project_id": project.id,
            "inspection_id": None,
            "officer_name": "Officer A",
            "representative_name": "Representative B",
        }

        response = client.post("/video-sessions", json=payload)

        assert response.status_code == 201
        data = response.json()
        assert data["project_id"] == project.id
        assert data["status"] == "CREATED"
        assert data["officer_name"] == "Officer A"
        assert data["representative_name"] == "Representative B"
        assert data["session_id"]
        UUID(data["session_id"])

        override_response = client.post(
            "/video-sessions",
            json={
                "project_id": project.id,
                "status": "ACTIVE",
                "session_id": "not-allowed",
                "officer_name": "Officer Override",
            },
        )
        assert override_response.status_code == 201
        assert override_response.json()["status"] == "CREATED"
        assert override_response.json()["session_id"] != "not-allowed"
    finally:
        db.close()


def test_create_video_session_for_missing_project_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.post(
        "/video-sessions",
        json={"project_id": 999, "officer_name": "Officer A"},
    )
    assert response.status_code == 404


def test_create_video_session_with_valid_inspection_same_project(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)

        response = client.post(
            "/video-sessions",
            json={
                "project_id": project.id,
                "inspection_id": inspection.id,
                "officer_name": "Officer A",
                "representative_name": "Representative B",
            },
        )

        assert response.status_code == 201
        data = response.json()
        assert data["inspection_id"] == inspection.id
        assert data["project_id"] == project.id
    finally:
        db.close()


def test_create_video_session_missing_inspection_returns_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/video-sessions",
            json={"project_id": project.id, "inspection_id": 999},
        )
        assert response.status_code == 404
    finally:
        db.close()


def test_create_video_session_inspection_from_other_project_returns_400(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")
        inspection_b = create_inspection(db, project_b.id)

        response = client.post(
            "/video-sessions",
            json={
                "project_id": project_a.id,
                "inspection_id": inspection_b.id,
                "officer_name": "Officer A",
            },
        )

        assert response.status_code == 400
    finally:
        db.close()


def test_get_video_session_by_id(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        session = VideoSession(
            project_id=project.id,
            session_id="550e8400-e29b-41d4-a716-446655440000",
            status="CREATED",
            officer_name="Officer A",
            representative_name="Representative B",
        )
        db.add(session)
        db.commit()
        db.refresh(session)

        response = client.get(f"/video-sessions/{session.id}")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == session.id
        assert data["session_id"] == session.session_id
    finally:
        db.close()


def test_get_missing_video_session_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.get("/video-sessions/999")
    assert response.status_code == 404


def test_list_project_video_sessions(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")

        first = VideoSession(
            project_id=project_a.id,
            session_id="550e8400-e29b-41d4-a716-446655440001",
            status="CREATED",
        )
        second = VideoSession(
            project_id=project_a.id,
            session_id="550e8400-e29b-41d4-a716-446655440002",
            status="ACTIVE",
        )
        third = VideoSession(
            project_id=project_b.id,
            session_id="550e8400-e29b-41d4-a716-446655440003",
            status="CREATED",
        )
        db.add_all([first, second, third])
        db.commit()

        response = client.get(f"/video-sessions/project/{project_a.id}")

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2
        assert [item["id"] for item in data] == [second.id, first.id]
        assert all(item["project_id"] == project_a.id for item in data)
    finally:
        db.close()


def test_project_video_sessions_no_sessions_returns_empty_list(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.get(f"/video-sessions/project/{project.id}")
        assert response.status_code == 200
        assert response.json() == []
    finally:
        db.close()


def test_project_video_sessions_missing_project_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.get("/video-sessions/project/999")
    assert response.status_code == 404


def test_project_video_sessions_isolation(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")

        session_a = VideoSession(project_id=project_a.id, session_id="550e8400-e29b-41d4-a716-446655440011", status="CREATED")
        session_b = VideoSession(project_id=project_b.id, session_id="550e8400-e29b-41d4-a716-446655440012", status="CREATED")
        db.add_all([session_a, session_b])
        db.commit()

        response = client.get(f"/video-sessions/project/{project_a.id}")

        assert response.status_code == 200
        ids = [item["id"] for item in response.json()]
        assert session_a.id in ids
        assert session_b.id not in ids
    finally:
        db.close()


def test_start_video_session_sets_started_at_and_status(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        session = VideoSession(project_id=project.id, session_id="550e8400-e29b-41d4-a716-446655440020", status="CREATED")
        db.add(session)
        db.commit()
        db.refresh(session)

        response = client.post(f"/video-sessions/{session.id}/start")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ACTIVE"
        assert data["started_at"] is not None
    finally:
        db.close()


def test_start_video_session_does_not_overwrite_started_at(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        started_at = datetime(2024, 1, 1, tzinfo=timezone.utc)
        session = VideoSession(
            project_id=project.id,
            session_id="550e8400-e29b-41d4-a716-446655440021",
            status="CREATED",
            started_at=started_at,
        )
        db.add(session)
        db.commit()
        db.refresh(session)

        response = client.post(f"/video-sessions/{session.id}/start")

        assert response.status_code == 200
        data = response.json()
        assert datetime.fromisoformat(data["started_at"]).replace(tzinfo=timezone.utc) == started_at
    finally:
        db.close()


def test_end_video_session_sets_ended_at_and_status(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        session = VideoSession(
            project_id=project.id,
            session_id="550e8400-e29b-41d4-a716-446655440030",
            status="ACTIVE",
            started_at=datetime.now(timezone.utc),
        )
        db.add(session)
        db.commit()
        db.refresh(session)

        response = client.post(f"/video-sessions/{session.id}/end")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ENDED"
        assert data["ended_at"] is not None
    finally:
        db.close()


def test_end_video_session_does_not_overwrite_ended_at(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        ended_at = datetime(2024, 2, 1, tzinfo=timezone.utc)
        session = VideoSession(
            project_id=project.id,
            session_id="550e8400-e29b-41d4-a716-446655440031",
            status="ACTIVE",
            started_at=datetime.now(timezone.utc),
            ended_at=ended_at,
        )
        db.add(session)
        db.commit()
        db.refresh(session)

        response = client.post(f"/video-sessions/{session.id}/end")

        assert response.status_code == 200
        data = response.json()
        assert datetime.fromisoformat(data["ended_at"]).replace(tzinfo=timezone.utc) == ended_at
    finally:
        db.close()


def test_cancel_video_session_sets_status(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        session = VideoSession(project_id=project.id, session_id="550e8400-e29b-41d4-a716-446655440040", status="CREATED")
        db.add(session)
        db.commit()
        db.refresh(session)

        response = client.post(f"/video-sessions/{session.id}/cancel")

        assert response.status_code == 200
        assert response.json()["status"] == "CANCELLED"
    finally:
        db.close()


def test_video_session_invalid_lifecycle_transitions_return_400(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        active_session = VideoSession(
            project_id=project.id,
            session_id="550e8400-e29b-41d4-a716-446655440050",
            status="ACTIVE",
            started_at=datetime.now(timezone.utc),
        )
        ended_session = VideoSession(
            project_id=project.id,
            session_id="550e8400-e29b-41d4-a716-446655440051",
            status="ENDED",
            started_at=datetime.now(timezone.utc),
            ended_at=datetime.now(timezone.utc),
        )
        cancelled_session = VideoSession(
            project_id=project.id,
            session_id="550e8400-e29b-41d4-a716-446655440052",
            status="CANCELLED",
        )
        db.add_all([active_session, ended_session, cancelled_session])
        db.commit()

        invalid_starts = [
            active_session.id,
            ended_session.id,
            cancelled_session.id,
        ]
        for session_id in invalid_starts:
            response = client.post(f"/video-sessions/{session_id}/start")
            assert response.status_code == 400

        invalid_ends = [
            ended_session.id,
            cancelled_session.id,
        ]
        for session_id in invalid_ends:
            response = client.post(f"/video-sessions/{session_id}/end")
            assert response.status_code == 400

        invalid_cancels = [
            active_session.id,
            ended_session.id,
            cancelled_session.id,
        ]
        for session_id in invalid_cancels:
            response = client.post(f"/video-sessions/{session_id}/cancel")
            assert response.status_code == 400
    finally:
        db.close()


def test_update_video_session_participant_fields_only(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        session = VideoSession(
            project_id=project.id,
            session_id="550e8400-e29b-41d4-a716-446655440060",
            status="CREATED",
            officer_name="Old Officer",
            representative_name="Old Representative",
        )
        db.add(session)
        db.commit()
        db.refresh(session)

        response = client.put(
            f"/video-sessions/{session.id}",
            json={
                "officer_name": "New Officer",
                "representative_name": "New Representative",
                "status": "ACTIVE",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["officer_name"] == "New Officer"
        assert data["representative_name"] == "New Representative"
        assert data["status"] == "CREATED"
    finally:
        db.close()
