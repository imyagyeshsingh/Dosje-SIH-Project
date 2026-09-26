from datetime import datetime, timezone
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.ai_detection import AIDetection
from app.models.attendance import Attendance
from app.models.camera import Camera
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


def create_project(db, name="Attendance Proj", code="PRJ-ATT-01"):
    project = Project(
        project_name=name,
        project_code=code,
        status="ACTIVE",
        progress=Decimal("10.0"),
    )
    db.add(project)
    db.commit()
    db.refresh(project)
    return project


def test_create_attendance_config_success(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        payload = {"project_id": project.id, "expected_workers": 50}
        response = client.post("/attendance", json=payload)
        assert response.status_code == 201
        data = response.json()
        assert data["project_id"] == project.id
        assert data["expected_workers"] == 50
    finally:
        db.close()


def test_create_attendance_duplicate_returns_409(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        payload = {"project_id": project.id, "expected_workers": 50}
        client.post("/attendance", json=payload)

        res2 = client.post("/attendance", json=payload)
        assert res2.status_code == 409
        assert "already exists" in res2.json()["detail"]
    finally:
        db.close()


def test_create_attendance_missing_project_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.post("/attendance", json={"project_id": 999999, "expected_workers": 10})
    assert response.status_code == 404
    assert response.json()["detail"] == "Project not found"


def test_get_attendance_config_success_and_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        # Not created yet
        res_none = client.get(f"/attendance/{project.id}")
        assert res_none.status_code == 404
        assert "not found for this project" in res_none.json()["detail"]

        client.post("/attendance", json={"project_id": project.id, "expected_workers": 30})
        res_found = client.get(f"/attendance/{project.id}")
        assert res_found.status_code == 200
        assert res_found.json()["expected_workers"] == 30

        # Nonexistent project
        assert client.get("/attendance/888888").status_code == 404
    finally:
        db.close()


def test_update_attendance_config_success(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        client.post("/attendance", json={"project_id": project.id, "expected_workers": 20})

        update_res = client.put(f"/attendance/{project.id}", json={"expected_workers": 45})
        assert update_res.status_code == 200
        assert update_res.json()["expected_workers"] == 45

        # Verify persisted
        get_res = client.get(f"/attendance/{project.id}")
        assert get_res.json()["expected_workers"] == 45
    finally:
        db.close()


def test_attendance_summary_with_and_without_detections(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        # Summary with no config and no detection
        s1 = client.get(f"/attendance/summary/{project.id}")
        assert s1.status_code == 200
        d1 = s1.json()
        assert d1["expected_workers"] is None
        assert d1["detected_workers"] is None
        assert d1["attendance_percentage"] is None

        # Add config: expected 50
        client.post("/attendance", json={"project_id": project.id, "expected_workers": 50})

        s2 = client.get(f"/attendance/summary/{project.id}")
        assert s2.status_code == 200
        d2 = s2.json()
        assert d2["expected_workers"] == 50
        assert d2["detected_workers"] is None
        assert d2["attendance_percentage"] is None

        # Add camera and detection
        camera = Camera(project_id=project.id, camera_name="C1", stream_url="rtsp://test/1")
        db.add(camera)
        db.commit()
        db.refresh(camera)

        det = AIDetection(
            project_id=project.id,
            camera_id=camera.id,
            people_detected=40,
            confidence=0.92,
            timestamp=datetime(2026, 9, 24, 8, 0, tzinfo=timezone.utc),
            activity="NORMAL",
        )
        db.add(det)
        db.commit()

        s3 = client.get(f"/attendance/summary/{project.id}")
        assert s3.status_code == 200
        d3 = s3.json()
        assert d3["expected_workers"] == 50
        assert d3["detected_workers"] == 40
        assert d3["attendance_percentage"] == 80.0
    finally:
        db.close()
