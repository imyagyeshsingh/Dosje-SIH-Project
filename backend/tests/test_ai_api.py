from datetime import datetime, timezone
from decimal import Decimal
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.models.ai_detection import AIDetection
from app.models.alert import Alert
from app.models.attendance import Attendance
from app.models.audit_log import AuditLog
from app.models.camera import Camera
from app.models.notification import Notification
from app.models.project import Project
from app.routers.ai import router as ai_router
from app.routers.alerts import router as alerts_router
from app.routers.attendance import router as attendance_router
from app.routers.cctv import router as cctv_router
from app.routers.projects import router as projects_router
from app.routers.risk import router as risk_router


def create_test_app() -> FastAPI:
    """Create a FastAPI application with the production AI routers for isolated testing.
    
    This avoids importing app.main directly which triggers the pre-existing Task 18
    ReportEvidenceReference mapper configuration issue.
    """
    app = FastAPI(title="DoSJE Test App - AI Integration")
    app.include_router(projects_router)
    app.include_router(cctv_router)
    app.include_router(ai_router)
    app.include_router(attendance_router)
    app.include_router(alerts_router)
    app.include_router(risk_router)
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


def create_project(session: Session, progress: Decimal = Decimal("50"), status: str = "ACTIVE") -> Project:
    project = Project(
        project_name="AI Test Project",
        project_code=f"AI-PROJ-{uuid4().hex[:8].upper()}",
        status=status,
        progress=progress,
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def create_camera(session: Session, project_id: int, camera_name: str = "Cam 1", status: str = "ACTIVE") -> Camera:
    camera = Camera(
        project_id=project_id,
        camera_name=camera_name,
        status=status,
    )
    session.add(camera)
    session.commit()
    session.refresh(camera)
    return camera


# 1. Valid AI detection creation
def test_create_ai_detection_success(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        payload = {
            "project_id": project.id,
            "camera_id": camera.id,
            "people_detected": 12,
            "activity": "LOW",
            "confidence": 0.91,
            "timestamp": "2026-09-22T14:30:00Z",
        }
        response = client.post("/ai/detection", json=payload)
        assert response.status_code == 201

        data = response.json()
        assert data["id"] is not None
        assert data["project_id"] == project.id
        assert data["camera_id"] == camera.id
        assert data["people_detected"] == 12
        assert data["activity"] == "LOW"
        assert abs(data["confidence"] - 0.91) < 0.001
        assert "created_at" in data
    finally:
        db.close()


# 2. Missing project returns 404
def test_create_ai_detection_missing_project(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        payload = {
            "project_id": 999999,
            "camera_id": camera.id,
            "people_detected": 5,
            "activity": "NORMAL",
            "confidence": 0.85,
            "timestamp": "2026-09-22T14:30:00Z",
        }
        response = client.post("/ai/detection", json=payload)
        assert response.status_code == 404
        assert "Project not found" in response.json()["detail"]
    finally:
        db.close()


# 3. Missing camera returns 404
def test_create_ai_detection_missing_camera(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)

        payload = {
            "project_id": project.id,
            "camera_id": 999999,
            "people_detected": 5,
            "activity": "NORMAL",
            "confidence": 0.85,
            "timestamp": "2026-09-22T14:30:00Z",
        }
        response = client.post("/ai/detection", json=payload)
        assert response.status_code == 404
        assert "Camera not found" in response.json()["detail"]
    finally:
        db.close()


# 4. Camera/project mismatch returns 400
def test_create_ai_detection_camera_project_mismatch(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db)
        project_b = create_project(db)
        camera_b = create_camera(db, project_b.id, camera_name="Cam B")

        payload = {
            "project_id": project_a.id,
            "camera_id": camera_b.id,
            "people_detected": 5,
            "activity": "NORMAL",
            "confidence": 0.85,
            "timestamp": "2026-09-22T14:30:00Z",
        }
        response = client.post("/ai/detection", json=payload)
        assert response.status_code == 400
        assert "Camera does not belong to the supplied project" in response.json()["detail"]
    finally:
        db.close()


# 5. Invalid people_detected (< 0) returns 422
def test_create_ai_detection_invalid_people_detected(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        payload = {
            "project_id": project.id,
            "camera_id": camera.id,
            "people_detected": -1,
            "activity": "NORMAL",
            "confidence": 0.85,
            "timestamp": "2026-09-22T14:30:00Z",
        }
        response = client.post("/ai/detection", json=payload)
        assert response.status_code == 422
    finally:
        db.close()


# 6. Invalid confidence (< 0.0 or > 1.0) returns 422
@pytest.mark.parametrize("bad_confidence", [-0.1, 1.01, 2.0])
def test_create_ai_detection_invalid_confidence(client_and_db, bad_confidence):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        payload = {
            "project_id": project.id,
            "camera_id": camera.id,
            "people_detected": 5,
            "activity": "NORMAL",
            "confidence": bad_confidence,
            "timestamp": "2026-09-22T14:30:00Z",
        }
        response = client.post("/ai/detection", json=payload)
        assert response.status_code == 422
    finally:
        db.close()


# 7. Invalid/empty activity returns 422
@pytest.mark.parametrize("bad_activity", ["", "   ", "DRONE_SPOTTED", "UNKNOWN_EVENT"])
def test_create_ai_detection_invalid_activity(client_and_db, bad_activity):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        payload = {
            "project_id": project.id,
            "camera_id": camera.id,
            "people_detected": 5,
            "activity": bad_activity,
            "confidence": 0.85,
            "timestamp": "2026-09-22T14:30:00Z",
        }
        response = client.post("/ai/detection", json=payload)
        assert response.status_code == 422
    finally:
        db.close()


# 8. Activity normalization & supported aliases
@pytest.mark.parametrize(
    "raw_input,expected_canonical",
    [
        # Canonical values
        ("NORMAL", "NORMAL"),
        ("LOW", "LOW"),
        ("NO_ACTIVITY", "NO_ACTIVITY"),
        ("HIGH", "HIGH"),
        ("SUSPICIOUS", "SUSPICIOUS"),
        # Case insensitivity & whitespace trimming
        ("  normal  ", "NORMAL"),
        ("low", "LOW"),
        (" no_activity ", "NO_ACTIVITY"),
        ("high", "HIGH"),
        (" suspicious ", "SUSPICIOUS"),
        # Aliases
        ("Workers present", "NORMAL"),
        ("Construction activity detected", "NORMAL"),
        ("Normal activity", "NORMAL"),
        ("Low activity", "LOW"),
        ("No activity", "NO_ACTIVITY"),
        ("none", "NO_ACTIVITY"),
        ("inactive", "NO_ACTIVITY"),
        ("High activity", "HIGH"),
        ("Suspicious activity", "SUSPICIOUS"),
        ("  suspicious   activity  ", "SUSPICIOUS"),
    ],
)
def test_create_ai_detection_activity_normalization(client_and_db, raw_input, expected_canonical):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        payload = {
            "project_id": project.id,
            "camera_id": camera.id,
            "people_detected": 8,
            "activity": raw_input,
            "confidence": 0.88,
            "timestamp": "2026-09-22T14:30:00Z",
        }
        response = client.post("/ai/detection", json=payload)
        assert response.status_code == 201
        assert response.json()["activity"] == expected_canonical

        # Check DB value is canonical
        detection_id = response.json()["id"]
        detection_in_db = db.get(AIDetection, detection_id)
        assert detection_in_db is not None
        assert detection_in_db.activity == expected_canonical
    finally:
        db.close()


# 9. AI detection persistence in database
def test_ai_detection_persists_in_database(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        payload = {
            "project_id": project.id,
            "camera_id": camera.id,
            "people_detected": 15,
            "activity": "Workers present",
            "confidence": 0.95,
            "timestamp": "2026-09-22T15:00:00Z",
        }
        response = client.post("/ai/detection", json=payload)
        assert response.status_code == 201
        detection_id = response.json()["id"]

        row = db.get(AIDetection, detection_id)
        assert row is not None
        assert row.project_id == project.id
        assert row.camera_id == camera.id
        assert row.people_detected == 15
        assert row.activity == "NORMAL"
        assert abs(float(row.confidence) - 0.95) < 0.001
        assert row.created_at is not None
    finally:
        db.close()


# 10. AI ingestion creates an audit log
def test_ai_ingestion_creates_audit_log(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        payload = {
            "project_id": project.id,
            "camera_id": camera.id,
            "people_detected": 10,
            "activity": "LOW",
            "confidence": 0.80,
            "timestamp": "2026-09-22T14:30:00Z",
        }
        response = client.post("/ai/detection", json=payload)
        assert response.status_code == 201
        detection_id = response.json()["id"]

        audit_entry = db.scalars(
            select(AuditLog).where(
                AuditLog.project_id == project.id,
                AuditLog.entity_type == "AI_DETECTION",
                AuditLog.entity_id == detection_id,
            )
        ).first()

        assert audit_entry is not None
        assert audit_entry.action == "CREATED"
        assert audit_entry.actor_id is None
        assert audit_entry.actor_name is None
        assert audit_entry.created_at is not None
    finally:
        db.close()


# 11. AI ingestion triggers existing downstream monitoring (alerts, audit, notifications)
def test_ai_ingestion_triggers_suspicious_alert_and_notification(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        payload = {
            "project_id": project.id,
            "camera_id": camera.id,
            "people_detected": 4,
            "activity": "Suspicious activity",
            "confidence": 0.92,
            "timestamp": "2026-09-22T16:00:00Z",
        }
        response = client.post("/ai/detection", json=payload)
        assert response.status_code == 201
        detection_id = response.json()["id"]

        # Alert should be generated automatically
        alert = db.scalars(
            select(Alert).where(
                Alert.project_id == project.id,
                Alert.alert_type == "AI_ACTIVITY",
                Alert.detection_id == detection_id,
            )
        ).first()

        assert alert is not None
        assert alert.severity == "HIGH"
        assert alert.message == "Suspicious activity detected by AI"
        assert alert.source == "AI_DETECTION"
        assert alert.status == "OPEN"

        # Notification should be generated automatically
        notification = db.scalars(
            select(Notification).where(
                Notification.project_id == project.id,
                Notification.alert_id == alert.id,
            )
        ).first()
        assert notification is not None
        assert notification.notification_type == "ALERT"
        assert notification.severity == "HIGH"
        assert notification.message == alert.message

        # Alert creation audit log should exist
        alert_audit = db.scalars(
            select(AuditLog).where(
                AuditLog.project_id == project.id,
                AuditLog.entity_type == "ALERT",
                AuditLog.entity_id == alert.id,
            )
        ).first()
        assert alert_audit is not None
        assert alert_audit.action == "CREATED"
    finally:
        db.close()


def test_ai_ingestion_no_activity_triggers_medium_alert(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        payload = {
            "project_id": project.id,
            "camera_id": camera.id,
            "people_detected": 0,
            "activity": "No activity",
            "confidence": 0.95,
            "timestamp": "2026-09-22T16:30:00Z",
        }
        response = client.post("/ai/detection", json=payload)
        assert response.status_code == 201
        detection_id = response.json()["id"]

        alert = db.scalars(
            select(Alert).where(
                Alert.project_id == project.id,
                Alert.alert_type == "AI_ACTIVITY",
                Alert.detection_id == detection_id,
            )
        ).first()

        assert alert is not None
        assert alert.severity == "MEDIUM"
        assert alert.message == "No activity detected by AI"
    finally:
        db.close()


def test_ai_ingestion_normal_triggers_no_activity_alert(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        payload = {
            "project_id": project.id,
            "camera_id": camera.id,
            "people_detected": 10,
            "activity": "Workers present",
            "confidence": 0.90,
            "timestamp": "2026-09-22T17:00:00Z",
        }
        response = client.post("/ai/detection", json=payload)
        assert response.status_code == 201

        activity_alerts = list(
            db.scalars(
                select(Alert).where(
                    Alert.project_id == project.id,
                    Alert.alert_type == "AI_ACTIVITY",
                )
            ).all()
        )
        assert len(activity_alerts) == 0
    finally:
        db.close()


# 12. Existing AI list endpoint (GET /ai/detection/{project_id})
def test_list_project_detections(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        for i, act in enumerate(["NORMAL", "LOW", "HIGH"]):
            client.post(
                "/ai/detection",
                json={
                    "project_id": project.id,
                    "camera_id": camera.id,
                    "people_detected": i + 5,
                    "activity": act,
                    "confidence": 0.85,
                    "timestamp": f"2026-09-22T10:0{i}:00Z",
                },
            )

        response = client.get(f"/ai/detection/{project.id}")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 3
        # Should be ordered newest first
        assert data[0]["activity"] == "HIGH"
        assert data[1]["activity"] == "LOW"
        assert data[2]["activity"] == "NORMAL"
    finally:
        db.close()


# 13. Existing AI summary endpoint (GET /ai/detection/{project_id}/summary)
def test_get_project_detection_summary(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        # Before any detections
        summary_empty = client.get(f"/ai/detection/{project.id}/summary")
        assert summary_empty.status_code == 200
        assert summary_empty.json()["detection_count"] == 0
        assert summary_empty.json()["latest_activity"] is None

        # After adding detections
        client.post(
            "/ai/detection",
            json={
                "project_id": project.id,
                "camera_id": camera.id,
                "people_detected": 7,
                "activity": "LOW",
                "confidence": 0.80,
                "timestamp": "2026-09-22T12:00:00Z",
            },
        )
        client.post(
            "/ai/detection",
            json={
                "project_id": project.id,
                "camera_id": camera.id,
                "people_detected": 14,
                "activity": "Workers present",
                "confidence": 0.94,
                "timestamp": "2026-09-22T13:00:00Z",
            },
        )

        summary_resp = client.get(f"/ai/detection/{project.id}/summary")
        assert summary_resp.status_code == 200
        summary = summary_resp.json()
        assert summary["detection_count"] == 2
        assert summary["latest_people_detected"] == 14
        assert summary["latest_activity"] == "NORMAL"
        assert abs(summary["latest_confidence"] - 0.94) < 0.001
    finally:
        db.close()

