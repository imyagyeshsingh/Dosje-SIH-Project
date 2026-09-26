from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.audit_log import AuditLog
from app.models.project import Project


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


def create_project(session, project_name: str = "Audit Project") -> Project:
    project = Project(
        project_name=project_name,
        project_code=f"AUD-{uuid4().hex[:8].upper()}",
        status="ACTIVE",
        progress=40,
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def test_create_and_list_audit_logs(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)

        response = client.post(
            "/audit-logs",
            json={
                "project_id": project.id,
                "entity_type": "inspection",
                "entity_id": 42,
                "action": "created",
                "actor_id": "OFF-77",
                "actor_name": "Inspector Jane",
                "details": "Inspection created automatically",
            },
        )

        assert response.status_code == 201
        data = response.json()
        assert data["entity_type"] == "inspection"
        assert data["action"] == "created"
        assert data["actor_id"] == "OFF-77"
        assert data["project_id"] == project.id
        assert data["details"] == "Inspection created automatically"

        list_response = client.get("/audit-logs", params={"project_id": project.id, "limit": 10})
        assert list_response.status_code == 200
        items = list_response.json()
        assert len(items) == 1
        assert items[0]["id"] == data["id"]

        project_response = client.get(f"/audit-logs/project/{project.id}")
        assert project_response.status_code == 200
        assert len(project_response.json()) == 1
    finally:
        db.close()


def test_audit_log_model_records_nullable_actor_and_timestamp(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        audit_log = AuditLog(
            project_id=project.id,
            entity_type="INSPECTION",
            entity_id=42,
            action="CREATED",
            actor_id=None,
            actor_name=None,
            details="Created without actor data",
        )
        db.add(audit_log)
        db.commit()
        db.refresh(audit_log)

        assert audit_log.id is not None
        assert audit_log.actor_id is None
        assert audit_log.actor_name is None
        assert audit_log.created_at is not None
        assert hasattr(audit_log, "user_id") is False
    finally:
        db.close()


def test_get_audit_log_returns_404_for_missing_record(client_and_db):
    client, _ = client_and_db

    response = client.get("/audit-logs/99999")

    assert response.status_code == 404


def test_audit_log_requires_nonblank_fields(client_and_db):
    client, _ = client_and_db

    response = client.post(
        "/audit-logs",
        json={
            "project_id": 1,
            "entity_type": "   ",
            "entity_id": 10,
            "action": "assigned",
        },
    )

    assert response.status_code == 422
