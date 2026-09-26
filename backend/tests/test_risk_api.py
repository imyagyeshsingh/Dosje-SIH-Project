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


def test_get_risk_nonexistent_project_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.get("/risk/999999")
    assert response.status_code == 404
    assert response.json()["detail"] == "Project not found"


def test_get_risk_default_project_signals(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = Project(
            project_name="Default Proj",
            project_code="PRJ-RISK-01",
            status="PLANNED",
        )
        db.add(project)
        db.commit()
        db.refresh(project)

        response = client.get(f"/risk/{project.id}")
        assert response.status_code == 200
        data = response.json()
        # Default project has progress=0.0 which evaluates to progress risk 100 (CRITICAL)
        assert data["score"] == 100
        assert data["level"] == "CRITICAL"
    finally:
        db.close()


def test_get_risk_progress_only_signal(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        # High progress >= 80 gives risk 0 (LOW)
        p_high = Project(project_name="P High", project_code="P-HIGH", progress=Decimal("85.0"))
        # Low progress < 20 gives risk 100 (CRITICAL)
        p_low = Project(project_name="P Low", project_code="P-LOW", progress=Decimal("10.0"))
        db.add_all([p_high, p_low])
        db.commit()

        r_high = client.get(f"/risk/{p_high.id}").json()
        assert r_high["score"] == 0
        assert r_high["level"] == "LOW"

        r_low = client.get(f"/risk/{p_low.id}").json()
        assert r_low["score"] == 100
        assert r_low["level"] == "CRITICAL"
    finally:
        db.close()


def test_get_risk_weighted_signals_combination(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = Project(project_name="Multi Signal", project_code="P-MULTI", progress=Decimal("50.0"))
        db.add(project)
        db.commit()
        db.refresh(project)

        # 1. Attendance: expected 100, detected 60 -> 60% -> risk 60 (weight 40)
        attendance = Attendance(project_id=project.id, expected_workers=100)
        db.add(attendance)

        # 2. Camera: 2 cameras, 1 active -> 50% -> risk 60 (weight 20)
        cam1 = Camera(project_id=project.id, camera_name="C1", stream_url="rtsp://t/1", status="ACTIVE")
        cam2 = Camera(project_id=project.id, camera_name="C2", stream_url="rtsp://t/2", status="INACTIVE")
        db.add_all([cam1, cam2])
        db.commit()

        # 3. Detection: 60 people, SUSPICIOUS activity -> risk 100 (weight 15)
        detection = AIDetection(
            project_id=project.id,
            camera_id=cam1.id,
            people_detected=60,
            activity="SUSPICIOUS",
            confidence=0.88,
            timestamp=datetime(2026, 9, 24, 8, 30, tzinfo=timezone.utc),
        )
        db.add(detection)
        db.commit()

        # Progress is 50.0 -> risk 50 (weight 25)
        # Expected calculation:
        # attendance: 60 * 40 = 2400
        # progress: 50 * 25 = 1250
        # cctv: 60 * 20 = 1200
        # activity: 100 * 15 = 1500
        # total_weight = 100
        # weighted_sum = 2400 + 1250 + 1200 + 1500 = 6350
        # score = 6350 / 100 = 64 (round) -> level HIGH (60-79)

        resp = client.get(f"/risk/{project.id}")
        assert resp.status_code == 200
        data = resp.json()
        assert data["score"] == 64
        assert data["level"] == "HIGH"
    finally:
        db.close()
