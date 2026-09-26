from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.inspection import Inspection
from app.models.project import Project
from app.models.report import Report


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
        project_code=f"PROJ-{project_name.lower().replace(' ', '-')}-{datetime.now(timezone.utc).timestamp()}",
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
        officer_name="Officer Sample",
        reason="Routine review",
    )
    session.add(inspection)
    session.commit()
    session.refresh(inspection)
    return inspection


def create_report(session, project_id: int, inspection_id: int, **overrides) -> Report:
    data = {
        "project_id": project_id,
        "inspection_id": inspection_id,
        "report_type": "INSPECTION",
        "status": "DRAFT",
        "title": "Report title",
        "summary": "Summary text",
        "findings": "Findings text",
        "recommendations": "Recommendation text",
    }
    data.update(overrides)
    report = Report(**data)
    session.add(report)
    session.commit()
    session.refresh(report)
    return report


def test_create_evidence_reference_for_existing_report(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)
        report = create_report(db, project.id, inspection.id, title="Evidence report")

        response = client.post(
            f"/reports/{report.id}/evidence",
            json={"external_evidence_id": "evt-001", "evidence_type": "IMAGE", "source": "camera-7"},
        )

        assert response.status_code == 201
        data = response.json()
        assert data["report_id"] == report.id
        assert data["external_evidence_id"] == "evt-001"
        assert data["evidence_type"] == "IMAGE"
        assert data["source"] == "camera-7"
    finally:
        db.close()


def test_create_evidence_reference_rejects_missing_report(client_and_db):
    client, _ = client_and_db
    response = client.post(
        "/reports/999/evidence",
        json={"external_evidence_id": "evt-001", "evidence_type": "IMAGE"},
    )
    assert response.status_code == 404


def test_get_evidence_references_for_report_returns_only_requested_report(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")
        inspection_a = create_inspection(db, project_a.id)
        inspection_b = create_inspection(db, project_b.id)
        report_a = create_report(db, project_a.id, inspection_a.id, title="Report A")
        report_b = create_report(db, project_b.id, inspection_b.id, title="Report B")

        first = client.post(
            f"/reports/{report_a.id}/evidence",
            json={"external_evidence_id": "evt-a-1", "evidence_type": "IMAGE"},
        )
        second = client.post(
            f"/reports/{report_b.id}/evidence",
            json={"external_evidence_id": "evt-b-1", "evidence_type": "VIDEO"},
        )

        assert first.status_code == 201
        assert second.status_code == 201

        response = client.get(f"/reports/{report_a.id}/evidence")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["report_id"] == report_a.id
        assert data[0]["external_evidence_id"] == "evt-a-1"
        assert data[0]["evidence_type"] == "IMAGE"
    finally:
        db.close()


def test_delete_evidence_reference_removes_only_requested_reference(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)
        report = create_report(db, project.id, inspection.id, title="Delete report")

        created = client.post(
            f"/reports/{report.id}/evidence",
            json={"external_evidence_id": "evt-delete", "evidence_type": "DOCUMENT"},
        )
        reference_id = created.json()["id"]

        delete_response = client.delete(f"/reports/{report.id}/evidence/{reference_id}")
        assert delete_response.status_code == 200
        assert delete_response.json()["message"] == "Evidence reference deleted successfully"

        get_response = client.get(f"/reports/{report.id}/evidence")
        assert get_response.status_code == 200
        assert get_response.json() == []
    finally:
        db.close()


def test_duplicate_evidence_reference_is_rejected(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)
        report = create_report(db, project.id, inspection.id, title="Duplicate test")

        first = client.post(
            f"/reports/{report.id}/evidence",
            json={"external_evidence_id": "evt-dup", "evidence_type": "IMAGE"},
        )
        second = client.post(
            f"/reports/{report.id}/evidence",
            json={"external_evidence_id": "evt-dup", "evidence_type": "IMAGE"},
        )

        assert first.status_code == 201
        assert second.status_code == 409
    finally:
        db.close()
