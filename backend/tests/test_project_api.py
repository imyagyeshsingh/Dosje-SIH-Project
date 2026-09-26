from datetime import date
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.alert import Alert
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


def test_create_project_minimal_success(client_and_db):
    client, _ = client_and_db
    payload = {
        "project_name": "Hostel Construction",
        "project_code": "PRJ-HOSTEL-001",
    }
    response = client.post("/projects", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["id"] is not None
    assert data["project_name"] == "Hostel Construction"
    assert data["project_code"] == "PRJ-HOSTEL-001"
    assert data["status"] == "PLANNED"
    assert Decimal(str(data["progress"])) == Decimal("0")


def test_create_project_full_success(client_and_db):
    client, _ = client_and_db
    payload = {
        "project_name": "Bridge Renovation",
        "project_code": "PRJ-BRIDGE-002",
        "description": "Major structural overhaul",
        "location": "Sector 4, New Delhi",
        "latitude": 28.6139,
        "longitude": 77.2090,
        "department": "Civil Infrastructure",
        "status": "ACTIVE",
        "start_date": "2026-01-01",
        "expected_end_date": "2026-12-31",
        "progress": 25.5,
    }
    response = client.post("/projects", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["project_name"] == "Bridge Renovation"
    assert data["status"] == "ACTIVE"
    assert Decimal(str(data["progress"])) == Decimal("25.5")
    assert data["start_date"] == "2026-01-01"
    assert data["expected_end_date"] == "2026-12-31"


def test_create_project_duplicate_code_returns_409(client_and_db):
    client, _ = client_and_db
    payload = {
        "project_name": "Project 1",
        "project_code": "DUP-CODE-001",
    }
    res1 = client.post("/projects", json=payload)
    assert res1.status_code == 201

    res2 = client.post("/projects", json={"project_name": "Project 2", "project_code": "DUP-CODE-001"})
    assert res2.status_code == 409
    assert "already exists" in res2.json()["detail"]


def test_create_project_invalid_dates_returns_422(client_and_db):
    client, _ = client_and_db
    payload = {
        "project_name": "Invalid Date Project",
        "project_code": "PRJ-DATE-ERR",
        "start_date": "2026-05-01",
        "expected_end_date": "2026-04-01",
    }
    response = client.post("/projects", json=payload)
    assert response.status_code == 422


def test_create_project_invalid_progress_returns_422(client_and_db):
    client, _ = client_and_db
    payload = {
        "project_name": "Bad Progress",
        "project_code": "PRJ-PROG-ERR",
        "progress": 150.0,
    }
    response = client.post("/projects", json=payload)
    assert response.status_code == 422


def test_get_project_success_and_404(client_and_db):
    client, _ = client_and_db
    created = client.post("/projects", json={"project_name": "P1", "project_code": "P1"}).json()
    project_id = created["id"]

    res_found = client.get(f"/projects/{project_id}")
    assert res_found.status_code == 200
    assert res_found.json()["project_code"] == "P1"

    res_missing = client.get("/projects/999999")
    assert res_missing.status_code == 404
    assert res_missing.json()["detail"] == "Project not found"


def test_list_projects_pagination(client_and_db):
    client, _ = client_and_db
    for i in range(5):
        client.post("/projects", json={"project_name": f"P{i}", "project_code": f"CODE-{i}"})

    list_res = client.get("/projects?limit=3&offset=0")
    assert list_res.status_code == 200
    data = list_res.json()
    assert len(data) == 3

    page2 = client.get("/projects?limit=3&offset=3")
    assert page2.status_code == 200
    assert len(page2.json()) == 2


def test_get_project_summary(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = Project(
            project_name="Summary Project",
            project_code="PRJ-SUMM-01",
            status="ACTIVE",
            progress=Decimal("50.0"),
        )
        db.add(project)
        db.commit()
        db.refresh(project)

        alert1 = Alert(
            project_id=project.id,
            alert_type="RISK",
            severity="HIGH",
            message="High risk detected",
            status="OPEN",
            source="RISK_ENGINE",
        )
        alert2 = Alert(
            project_id=project.id,
            alert_type="CAMERA",
            severity="LOW",
            message="Camera offline",
            status="RESOLVED",
            source="CAMERA_MONITOR",
        )
        db.add_all([alert1, alert2])
        db.commit()

        summary_res = client.get(f"/projects/{project.id}/summary")
        assert summary_res.status_code == 200
        summary_data = summary_res.json()
        assert summary_data["project"]["id"] == project.id
        assert summary_data["alerts"]["total"] == 2
        assert summary_data["alerts"]["active"] == 1
        assert "risk" in summary_data
    finally:
        db.close()


def test_update_project_success_and_validation(client_and_db):
    client, _ = client_and_db
    created = client.post("/projects", json={"project_name": "P-Update", "project_code": "PRJ-UPD-01"}).json()
    project_id = created["id"]

    update_payload = {
        "project_name": "P-Updated-Name",
        "status": "ACTIVE",
        "progress": 60.0,
    }
    update_res = client.put(f"/projects/{project_id}", json=update_payload)
    assert update_res.status_code == 200
    updated_data = update_res.json()
    assert updated_data["project_name"] == "P-Updated-Name"
    assert updated_data["status"] == "ACTIVE"
    assert Decimal(str(updated_data["progress"])) == Decimal("60")

    # Update with invalid dates
    bad_dates = client.put(
        f"/projects/{project_id}",
        json={"start_date": "2026-06-01", "expected_end_date": "2026-01-01"},
    )
    assert bad_dates.status_code == 422

    # Update nonexistent project
    missing_res = client.put("/projects/999999", json={"project_name": "Doesn't exist"})
    assert missing_res.status_code == 404
