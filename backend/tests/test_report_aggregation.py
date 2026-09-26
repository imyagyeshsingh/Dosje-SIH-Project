from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.ai_detection import AIDetection
from app.models.alert import Alert
from app.models.attendance import Attendance
from app.models.camera import Camera
from app.models.inspection import Inspection
from app.models.project import Project
from app.models.report import Report
from app.models.report_evidence_reference import ReportEvidenceReference
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
        project_code=f"PROJ-{project_name.lower().replace(' ', '-')}-{datetime.now(timezone.utc).timestamp()}",
        status="ACTIVE",
        progress=50,
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def create_report(session, project_id: int, inspection_id: int, **overrides) -> Report:
    data = {
        "project_id": project_id,
        "inspection_id": inspection_id,
        "report_type": "INSPECTION",
        "status": "DRAFT",
        "title": "Monitoring report",
        "summary": "Summary",
        "findings": "Findings",
        "recommendations": "Recommendations",
    }
    data.update(overrides)
    report = Report(**data)
    session.add(report)
    session.commit()
    session.refresh(report)
    return report


def create_inspection(session, project_id: int, status: str = "PENDING") -> Inspection:
    inspection = Inspection(
        project_id=project_id,
        inspection_type="MANUAL",
        status=status,
        officer_name="Officer A",
        reason="Routine review",
    )
    session.add(inspection)
    session.commit()
    session.refresh(inspection)
    return inspection


def create_ai_detection(session, project_id: int, *, people_detected: int = 8, activity: str = "HIGH", confidence: float = 0.91) -> AIDetection:
    detection = AIDetection(
        project_id=project_id,
        camera_id=1,
        people_detected=people_detected,
        activity=activity,
        confidence=confidence,
        timestamp=datetime.now(timezone.utc),
    )
    session.add(detection)
    session.commit()
    session.refresh(detection)
    return detection


def test_report_aggregation_returns_project_snapshot(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db, "Project A")
        inspection = create_inspection(db, project.id)
        report = create_report(db, project.id, inspection.id, title="Aggregated report")

        db.add(Attendance(project_id=project.id, expected_workers=10))
        db.add(Camera(project_id=project.id, camera_name="Cam 1", status="ACTIVE"))
        db.add(Camera(project_id=project.id, camera_name="Cam 2", status="INACTIVE"))
        detection = create_ai_detection(db, project.id, people_detected=8, activity="HIGH", confidence=0.91)
        db.add(Alert(project_id=project.id, alert_type="AI_ACTIVITY", severity="HIGH", message="Movement detected", confidence=0.85, status="OPEN"))
        db.add(Alert(project_id=project.id, alert_type="RISK", severity="MEDIUM", message="Elevated risk", confidence=0.6, status="RESOLVED"))
        db.add(Inspection(project_id=project.id, inspection_type="SCHEDULED", status="SCHEDULED", officer_name="Inspector 1"))
        db.add(Inspection(project_id=project.id, inspection_type="MANUAL", status="COMPLETED", officer_name="Inspector 2"))
        db.add(
            VideoSession(
                project_id=project.id,
                inspection_id=inspection.id,
                session_id="video-1",
                status="ACTIVE",
                officer_name="Officer 1",
            )
        )
        db.add(
            ReportEvidenceReference(
                report_id=report.id,
                external_evidence_id="evidence-a-1",
                evidence_type="IMAGE",
                source="camera-1",
            )
        )
        db.commit()

        response = client.get(f"/reports/{report.id}/aggregation")

        assert response.status_code == 200
        data = response.json()
        assert data["report_id"] == report.id
        assert data["project_id"] == project.id
        assert data["risk"]["score"] is not None
        assert data["attendance"]["expected_workers"] == 10
        assert data["attendance"]["detected_workers"] == 8
        assert data["cctv"]["total_cameras"] == 2
        assert data["cctv"]["active_cameras"] == 1
        assert data["ai"]["total_detections"] >= 1
        assert data["ai"]["latest_activity"] == "HIGH"
        assert data["alerts"]["total_alerts"] == 2
        assert data["alerts"]["active_alerts"] == 1
        assert data["inspections"]["total_inspections"] >= 2
        assert data["video_sessions"]["total_sessions"] == 1
        assert data["evidence"]["total_references"] == 1
        assert data["inspection"]["id"] == inspection.id
    finally:
        db.close()


def test_report_aggregation_rejects_missing_report(client_and_db):
    client, _ = client_and_db
    response = client.get("/reports/999/aggregation")
    assert response.status_code == 404


def test_report_aggregation_is_project_scoped(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")
        inspection_a = create_inspection(db, project_a.id)
        inspection_b = create_inspection(db, project_b.id)
        report_a = create_report(db, project_a.id, inspection_a.id, title="Report A")
        report_b = create_report(db, project_b.id, inspection_b.id, title="Report B")

        db.add(Attendance(project_id=project_a.id, expected_workers=8))
        db.add(Attendance(project_id=project_b.id, expected_workers=20))
        db.add(Camera(project_id=project_a.id, camera_name="A1", status="ACTIVE"))
        db.add(Camera(project_id=project_b.id, camera_name="B1", status="ACTIVE"))
        db.add(Camera(project_id=project_b.id, camera_name="B2", status="INACTIVE"))
        db.add(AIDetection(project_id=project_a.id, camera_id=1, people_detected=5, activity="LOW", confidence=0.70, timestamp=datetime.now(timezone.utc)))
        db.add(AIDetection(project_id=project_b.id, camera_id=1, people_detected=20, activity="SUSPICIOUS", confidence=0.95, timestamp=datetime.now(timezone.utc)))
        db.add(Alert(project_id=project_a.id, alert_type="AI_ACTIVITY", severity="HIGH", message="A alert", confidence=0.8, status="OPEN"))
        db.add(Alert(project_id=project_b.id, alert_type="AI_ACTIVITY", severity="HIGH", message="B alert", confidence=0.8, status="OPEN"))
        db.add(Inspection(project_id=project_a.id, inspection_type="MANUAL", status="PENDING", officer_name="Officer A"))
        db.add(Inspection(project_id=project_b.id, inspection_type="MANUAL", status="PENDING", officer_name="Officer B"))
        db.add(VideoSession(project_id=project_a.id, session_id="video-a", status="ENDED"))
        db.add(VideoSession(project_id=project_b.id, session_id="video-b", status="ACTIVE"))
        db.add(ReportEvidenceReference(report_id=report_a.id, external_evidence_id="a-1", evidence_type="IMAGE", source="cam-a"))
        db.add(ReportEvidenceReference(report_id=report_b.id, external_evidence_id="b-1", evidence_type="VIDEO", source="cam-b"))
        db.commit()

        response = client.get(f"/reports/{report_a.id}/aggregation")

        assert response.status_code == 200
        data = response.json()
        assert data["project_id"] == project_a.id
        assert data["attendance"]["expected_workers"] == 8
        assert data["cctv"]["total_cameras"] == 1
        assert data["ai"]["total_detections"] == 1
        assert data["alerts"]["total_alerts"] == 1
        assert data["inspections"]["total_inspections"] == 2
        assert data["video_sessions"]["total_sessions"] == 1
        assert data["evidence"]["total_references"] == 1
        assert data["evidence"]["project_evidence_ids"] == ["a-1"]
    finally:
        db.close()


def test_report_aggregation_handles_empty_project_data(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db, "Empty Project")
        inspection = create_inspection(db, project.id)
        report = create_report(db, project.id, inspection.id, title="Empty report")

        response = client.get(f"/reports/{report.id}/aggregation")

        assert response.status_code == 200
        data = response.json()
        assert data["project_id"] == project.id
        assert data["risk"]["score"] == 50
        assert data["risk"]["level"] == "MEDIUM"
        assert data["attendance"]["expected_workers"] is None
        assert data["cctv"]["total_cameras"] == 0
        assert data["cctv"]["active_cameras"] == 0
        assert data["ai"]["total_detections"] == 0
        assert data["alerts"]["total_alerts"] == 0
        assert data["inspections"]["total_inspections"] == 1
        assert data["video_sessions"]["total_sessions"] == 0
        assert data["evidence"]["total_references"] == 0
    finally:
        db.close()
