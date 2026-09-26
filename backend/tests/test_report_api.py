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
        "title": "Default report title",
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


def test_create_report_success(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)

        response = client.post(
            "/reports",
            json={
                "project_id": project.id,
                "inspection_id": inspection.id,
                "report_type": "INSPECTION",
                "status": "FINAL",
                "title": "Site inspection report",
                "summary": "Summary text",
                "findings": "The worksite had an issue",
                "recommendations": "Follow up with site team",
            },
        )

        assert response.status_code == 201
        data = response.json()
        assert data["project_id"] == project.id
        assert data["inspection_id"] == inspection.id
        assert data["report_type"] == "INSPECTION"
        assert data["status"] == "FINAL"
        assert data["title"] == "Site inspection report"
    finally:
        db.close()


def test_create_report_missing_project_returns_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        inspection = create_inspection(db, 1)
        response = client.post(
            "/reports",
            json={
                "project_id": 999,
                "inspection_id": inspection.id,
                "report_type": "MONITORING",
                "status": "DRAFT",
                "title": "Missing project report",
            },
        )
        assert response.status_code == 404
    finally:
        db.close()


def test_create_report_missing_inspection_returns_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/reports",
            json={
                "project_id": project.id,
                "inspection_id": 999,
                "report_type": "INCIDENT",
                "status": "DRAFT",
                "title": "Missing inspection report",
            },
        )
        assert response.status_code == 404
    finally:
        db.close()


def test_create_report_rejects_project_inspection_mismatch(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")
        inspection_b = create_inspection(db, project_b.id)

        response = client.post(
            "/reports",
            json={
                "project_id": project_a.id,
                "inspection_id": inspection_b.id,
                "report_type": "INSPECTION",
                "status": "DRAFT",
                "title": "Wrong project report",
            },
        )

        assert response.status_code == 400
    finally:
        db.close()


def test_get_report_by_id(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)
        report = create_report(db, project.id, inspection.id, title="Existing report")

        response = client.get(f"/reports/{report.id}")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == report.id
        assert data["title"] == "Existing report"
    finally:
        db.close()


def test_get_report_missing_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.get("/reports/999")
    assert response.status_code == 404


def test_list_reports_for_project_returns_only_correct_project(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")
        inspection_a_1 = create_inspection(db, project_a.id, "SCHEDULED")
        inspection_a_2 = create_inspection(db, project_a.id, "MANUAL")
        inspection_b_1 = create_inspection(db, project_b.id, "RANDOM")

        first_report = create_report(db, project_a.id, inspection_a_1.id, title="Older report")
        second_report = create_report(db, project_a.id, inspection_a_2.id, title="Newest report")
        create_report(db, project_b.id, inspection_b_1.id, title="Other project report")

        response = client.get(f"/reports/project/{project_a.id}")

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2
        assert [item["id"] for item in data] == [second_report.id, first_report.id]
        assert all(item["project_id"] == project_a.id for item in data)
    finally:
        db.close()


def test_list_reports_for_nonexistent_project_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.get("/reports/project/999")
    assert response.status_code == 404


def test_project_with_no_reports_returns_empty_list(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.get(f"/reports/project/{project.id}")
        assert response.status_code == 200
        assert response.json() == []
    finally:
        db.close()


def test_cross_project_report_isolation(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")
        inspection_a = create_inspection(db, project_a.id)
        inspection_b = create_inspection(db, project_b.id)

        report_a = create_report(db, project_a.id, inspection_a.id, title="Project A report")
        create_report(db, project_b.id, inspection_b.id, title="Project B report")

        response = client.get(f"/reports/project/{project_a.id}")

        assert response.status_code == 200
        ids = [item["id"] for item in response.json()]
        assert report_a.id in ids
        assert all(item["project_id"] == project_a.id for item in response.json())
    finally:
        db.close()


def test_update_report_success(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)
        report = create_report(db, project.id, inspection.id, title="Original title", status="DRAFT")

        response = client.put(
            f"/reports/{report.id}",
            json={
                "status": "FINAL",
                "title": "Updated title",
                "summary": "Updated summary",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "FINAL"
        assert data["title"] == "Updated title"
        assert data["summary"] == "Updated summary"
    finally:
        db.close()


def test_partial_update_preserves_unspecified_fields(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)
        report = create_report(
            db,
            project.id,
            inspection.id,
            title="Original title",
            status="DRAFT",
            summary="Original summary",
            findings="Original findings",
        )

        response = client.put(
            f"/reports/{report.id}",
            json={"title": "Changed title"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "Changed title"
        assert data["status"] == "DRAFT"
        assert data["summary"] == "Original summary"
        assert data["findings"] == "Original findings"
    finally:
        db.close()


def test_invalid_report_enum_values_are_rejected(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)

        invalid_type = client.post(
            "/reports",
            json={
                "project_id": project.id,
                "inspection_id": inspection.id,
                "report_type": "INVALID",
                "status": "DRAFT",
                "title": "Bad type",
            },
        )
        invalid_status = client.post(
            "/reports",
            json={
                "project_id": project.id,
                "inspection_id": inspection.id,
                "report_type": "INSPECTION",
                "status": "INVALID",
                "title": "Bad status",
            },
        )

        assert invalid_type.status_code == 422
        assert invalid_status.status_code == 422
    finally:
        db.close()


def test_update_report_missing_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.put("/reports/999", json={"status": "FINAL"})
    assert response.status_code == 404


# --- Task 21A: report title whitespace validation ---

def test_create_report_with_whitespace_only_title_returns_422(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)
        response = client.post(
            "/reports",
            json={
                "project_id": project.id,
                "inspection_id": inspection.id,
                "report_type": "INSPECTION",
                "status": "DRAFT",
                "title": "   \t  ",
                "summary": "Summary",
                "findings": "Findings",
                "recommendations": "Recs",
            },
        )
        assert response.status_code == 422
    finally:
        db.close()


def test_update_report_with_whitespace_only_title_returns_422(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)
        report = create_report(db, project.id, inspection.id, title="Original title", status="DRAFT")

        response = client.put(
            f"/reports/{report.id}",
            json={"title": "  "},
        )
        assert response.status_code == 422
    finally:
        db.close()
