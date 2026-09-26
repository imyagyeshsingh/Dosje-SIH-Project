from datetime import datetime
from decimal import Decimal
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.ai_detection import AIDetection
from app.models.alert import Alert
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


def create_project(session) -> Project:
    project = Project(
        project_name="Project A",
        project_code=f"PROJ-A-{uuid4().hex[:8].upper()}",
        status="ACTIVE",
        progress=Decimal("50"),
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def create_camera(session, project_id: int) -> Camera:
    camera = Camera(
        project_id=project_id,
        camera_name="Main Camera",
        stream_url="rtsp://example/stream",
        status="ACTIVE",
    )
    session.add(camera)
    session.commit()
    session.refresh(camera)
    return camera


def create_detection(session, project_id: int, camera_id: int) -> AIDetection:
    detection = AIDetection(
        project_id=project_id,
        camera_id=camera_id,
        people_detected=17,
        activity="NORMAL",
        confidence=Decimal("0.94"),
        timestamp=datetime(2026, 9, 20, 5, 0, 0),
    )
    session.add(detection)
    session.commit()
    session.refresh(detection)
    return detection


def test_create_alert_success(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)
        detection = create_detection(db, project.id, camera.id)
        payload = {
            "project_id": project.id,
            "alert_type": "AI_ACTIVITY",
            "severity": "HIGH",
            "message": "Suspicious activity detected",
            "confidence": 0.94,
            "status": "OPEN",
            "source": "AI",
            "detection_id": detection.id,
        }
        response = client.post("/alerts", json=payload)
        assert response.status_code == 201
        data = response.json()
        assert data["project_id"] == project.id
        assert data["alert_type"] == "AI_ACTIVITY"
        assert data["severity"] == "HIGH"
        assert data["message"] == "Suspicious activity detected"
        assert data["status"] == "OPEN"
    finally:
        db.close()


def test_create_alert_for_nonexistent_project(client_and_db):
    client, _ = client_and_db
    response = client.post(
        "/alerts",
        json={
            "project_id": 999,
            "alert_type": "AI_ACTIVITY",
            "severity": "HIGH",
            "message": "Project missing",
        },
    )
    assert response.status_code == 404


def test_create_alert_with_nonexistent_detection(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        payload = {
            "project_id": project.id,
            "alert_type": "AI_ACTIVITY",
            "severity": "HIGH",
            "message": "Bad detection",
            "detection_id": 999,
        }
        response = client.post("/alerts", json=payload)
        assert response.status_code == 404
    finally:
        db.close()


def test_create_alert_with_detection_from_other_project(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db)
        project_b = create_project(db)
        camera_a = create_camera(db, project_a.id)
        camera_b = create_camera(db, project_b.id)
        detection = create_detection(db, project_b.id, camera_b.id)
        payload = {
            "project_id": project_a.id,
            "alert_type": "AI_ACTIVITY",
            "severity": "HIGH",
            "message": "Wrong project",
            "detection_id": detection.id,
        }
        response = client.post("/alerts", json=payload)
        assert response.status_code == 400
    finally:
        db.close()


def test_invalid_alert_severity_rejected(client_and_db):
    client, _ = client_and_db
    response = client.post(
        "/alerts",
        json={
            "project_id": 1,
            "alert_type": "AI_ACTIVITY",
            "severity": "INVALID",
            "message": "Bad severity",
        },
    )
    assert response.status_code == 422


def test_invalid_alert_status_rejected(client_and_db):
    client, _ = client_and_db
    response = client.post(
        "/alerts",
        json={
            "project_id": 1,
            "alert_type": "AI_ACTIVITY",
            "severity": "HIGH",
            "message": "Bad status",
            "status": "INVALID",
        },
    )
    assert response.status_code == 422


def test_get_alert_success(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        alert = Alert(
            project_id=project.id,
            alert_type="RISK",
            severity="MEDIUM",
            message="Test alert",
            status="OPEN",
        )
        db.add(alert)
        db.commit()
        db.refresh(alert)
        response = client.get(f"/alerts/{alert.id}")
        assert response.status_code == 200
        assert response.json()["id"] == alert.id
    finally:
        db.close()


def test_get_alert_not_found(client_and_db):
    client, _ = client_and_db
    response = client.get("/alerts/999")
    assert response.status_code == 404


def test_list_project_alerts_returns_newest_first(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db)
        project_b = create_project(db)
        first = Alert(
            project_id=project_a.id,
            alert_type="RISK",
            severity="LOW",
            message="older alert",
            status="OPEN",
            created_at=datetime(2026, 9, 20, 6, 0, 0),
            updated_at=datetime(2026, 9, 20, 6, 0, 0),
        )
        second = Alert(
            project_id=project_a.id,
            alert_type="AI_ACTIVITY",
            severity="HIGH",
            message="newer alert",
            status="OPEN",
            created_at=datetime(2026, 9, 20, 7, 0, 0),
            updated_at=datetime(2026, 9, 20, 7, 0, 0),
        )
        third = Alert(
            project_id=project_b.id,
            alert_type="CAMERA",
            severity="CRITICAL",
            message="other project",
            status="OPEN",
            created_at=datetime(2026, 9, 20, 8, 0, 0),
            updated_at=datetime(2026, 9, 20, 8, 0, 0),
        )
        db.add_all([first, second, third])
        db.commit()
        response = client.get(f"/alerts/project/{project_a.id}")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2
        assert data[0]["message"] == "newer alert"
        assert data[1]["message"] == "older alert"
    finally:
        db.close()


def test_list_project_alerts_no_alerts_returns_empty_list(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.get(f"/alerts/project/{project.id}")
        assert response.status_code == 200
        assert response.json() == []
    finally:
        db.close()


def test_list_project_alerts_nonexistent_project_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.get("/alerts/project/999")
    assert response.status_code == 404


def test_update_alert_status_success(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        alert = Alert(
            project_id=project.id,
            alert_type="RISK",
            severity="MEDIUM",
            message="Status change",
            status="OPEN",
        )
        db.add(alert)
        db.commit()
        db.refresh(alert)

        response = client.put(f"/alerts/{alert.id}/status", json={"status": "ACKNOWLEDGED"})
        assert response.status_code == 200
        assert response.json()["status"] == "ACKNOWLEDGED"

        response = client.put(f"/alerts/{alert.id}/status", json={"status": "RESOLVED"})
        assert response.status_code == 200
        assert response.json()["status"] == "RESOLVED"
    finally:
        db.close()


def test_update_alert_status_invalid_rejected(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        alert = Alert(
            project_id=project.id,
            alert_type="RISK",
            severity="MEDIUM",
            message="Bad status",
            status="OPEN",
        )
        db.add(alert)
        db.commit()
        db.refresh(alert)
        response = client.put(f"/alerts/{alert.id}/status", json={"status": "WRONG"})
        assert response.status_code == 422
    finally:
        db.close()


def test_update_alert_status_not_found(client_and_db):
    client, _ = client_and_db
    response = client.put("/alerts/999/status", json={"status": "ACKNOWLEDGED"})
    assert response.status_code == 404


def test_project_summary_and_risk_and_ai_detection_still_work(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)
        create_detection(db, project.id, camera.id)

        risk_response = client.get(f"/risk/{project.id}")
        assert risk_response.status_code == 200

        summary_response = client.get(f"/projects/{project.id}/summary")
        assert summary_response.status_code == 200
        assert summary_response.json()["alerts"] == {"total": 0, "active": 0}

        ai_response = client.post(
            "/ai/detection",
            json={
                "project_id": project.id,
                "camera_id": camera.id,
                "people_detected": 5,
                "activity": "LOW",
                "confidence": 0.81,
                "timestamp": "2026-09-20T06:00:00Z",
            },
        )
        assert ai_response.status_code == 201
    finally:
        db.close()


# --- Task 21A: whitespace validation ---

def test_create_project_with_whitespace_only_name_returns_422(client_and_db):
    client, _ = client_and_db
    response = client.post(
        "/projects",
        json={
            "project_name": "   ",
            "project_code": "WS-001",
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
            "project_code": "\t",
            "status": "ACTIVE",
            "progress": 50,
        },
    )
    assert response.status_code == 422


def test_create_project_strips_leading_trailing_whitespace(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        response = client.post(
            "/projects",
            json={
                "project_name": "  Trimmed Project  ",
                "project_code": "  TRIM-001  ",
                "status": "ACTIVE",
                "progress": 50,
            },
        )
        assert response.status_code == 201
        data = response.json()
        assert data["project_name"] == "Trimmed Project"
        assert data["project_code"] == "TRIM-001"
    finally:
        db.close()


def test_create_camera_with_whitespace_only_name_returns_422(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/cctv",
            json={
                "project_id": project.id,
                "camera_name": "   ",
                "stream_url": "rtsp://example.com/stream",
                "status": "ACTIVE",
            },
        )
        assert response.status_code == 422
    finally:
        db.close()


def test_create_camera_strips_camera_name(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/cctv",
            json={
                "project_id": project.id,
                "camera_name": "  Front Cam  ",
                "stream_url": "rtsp://example.com/stream",
                "status": "ACTIVE",
            },
        )
        assert response.status_code == 201
        assert response.json()["camera_name"] == "Front Cam"
    finally:
        db.close()


# --- Task 21A: media/source validation ---

def test_create_camera_with_malformed_stream_url_returns_422(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/cctv",
            json={
                "project_id": project.id,
                "camera_name": "Bad Stream Cam",
                "stream_url": "ht!tp://bad||url",
                "status": "ACTIVE",
            },
        )
        assert response.status_code == 422
    finally:
        db.close()


def test_create_camera_with_stream_url_containing_spaces_returns_422(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/cctv",
            json={
                "project_id": project.id,
                "camera_name": "Space Cam",
                "stream_url": "rtsp://example com/stream",
                "status": "ACTIVE",
            },
        )
        assert response.status_code == 422
    finally:
        db.close()


def test_create_camera_with_malformed_video_path_returns_422(client_and_db):
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


def test_create_camera_accepts_valid_video_path(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/cctv",
            json={
                "project_id": project.id,
                "camera_name": "Path Cam",
                "video_path": "/var/lib/videos/cam1.mp4",
                "status": "ACTIVE",
            },
        )
        assert response.status_code == 201
        assert response.json()["video_path"] == "/var/lib/videos/cam1.mp4"
    finally:
        db.close()
