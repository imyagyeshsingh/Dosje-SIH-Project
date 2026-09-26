from datetime import datetime, timezone
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.alert import Alert
from app.models.audit_log import AuditLog
from app.models.camera import Camera
from app.models.inspection import Inspection
from app.models.inspector import Inspector
from app.models.notification import Notification
from app.models.project import Project
from app.models.report import Report
from app.models.report_evidence_reference import ReportEvidenceReference


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


def test_complete_end_to_end_operational_flow(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        # 1. Create Project
        proj_payload = {
            "project_name": "Integrated Hospital Build",
            "project_code": "PRJ-E2E-HOSPITAL",
            "location": "Sector 18, Lucknow",
            "latitude": 26.8467,
            "longitude": 80.9462,
            "status": "ACTIVE",
            "progress": 35.0,
        }
        res_proj = client.post("/projects", json=proj_payload)
        assert res_proj.status_code == 201
        project_id = res_proj.json()["id"]

        # 2. Create Inspector
        insp_payload = {
            "inspector_id": "OFF-E2E-01",
            "inspector_name": "Dr. Ramesh Verma",
            "is_active": True,
        }
        res_insp = client.post("/inspectors", json=insp_payload)
        assert res_insp.status_code == 201

        # 3. Create Camera
        cam_payload = {
            "project_id": project_id,
            "camera_name": "Gate Camera 1",
            "stream_url": "rtsp://streams.example.com/live/gate1",
            "status": "ACTIVE",
        }
        res_cam = client.post("/cctv", json=cam_payload)
        assert res_cam.status_code == 201
        camera_id = res_cam.json()["id"]

        # 4. Create Inspection
        inspection_payload = {
            "project_id": project_id,
            "inspection_type": "MANUAL",
            "status": "PENDING",
            "reason": "Quarterly physical progress verification",
        }
        res_inspection = client.post("/inspections", json=inspection_payload)
        assert res_inspection.status_code == 201
        inspection_id = res_inspection.json()["id"]

        # 5. Assign Inspector
        assign_payload = {
            "inspector_id": "OFF-E2E-01",
            "inspector_name": "Dr. Ramesh Verma",
        }
        res_assign = client.post(f"/inspections/{inspection_id}/assign", json=assign_payload)
        assert res_assign.status_code == 200
        assert res_assign.json()["officer_id"] == "OFF-E2E-01"
        assert res_assign.json()["assignment_status"] == "ASSIGNED"

        # 6. Verify Location (within 100m radius of project coordinates)
        loc_payload = {
            "latitude": 26.84675,
            "longitude": 80.94625,
            "location_accuracy": 5.0,
        }
        res_loc = client.post(f"/inspections/{inspection_id}/location", json=loc_payload)
        assert res_loc.status_code == 200
        assert res_loc.json()["location_verified"] is True

        # 7. Create AI Detection
        detection_payload = {
            "project_id": project_id,
            "camera_id": camera_id,
            "people_detected": 42,
            "confidence": 0.94,
            "activity": "NORMAL",
            "timestamp": "2026-09-24T08:00:00Z",
        }
        res_det = client.post("/ai/detection", json=detection_payload)
        assert res_det.status_code == 201

        # 8. Calculate Risk
        res_risk = client.get(f"/risk/{project_id}")
        assert res_risk.status_code == 200
        risk_data = res_risk.json()
        assert risk_data["score"] is not None
        assert risk_data["level"] is not None

        # 9. Generate Alert
        res_alert = client.post(f"/alerts/generate/{project_id}")
        assert res_alert.status_code == 200

        # 10. Check Notifications
        res_notifs = client.get(f"/notifications/project/{project_id}")
        assert res_notifs.status_code == 200
        notifs = res_notifs.json()
        assert len(notifs) >= 1

        # 11. Create Report
        report_payload = {
            "project_id": project_id,
            "inspection_id": inspection_id,
            "report_type": "INSPECTION",
            "status": "FINAL",
            "title": "Quarterly Inspection Evaluation Report",
            "summary": "Physical progress aligns with structural timeline.",
        }
        res_report = client.post("/reports", json=report_payload)
        assert res_report.status_code == 201
        report_id = res_report.json()["id"]

        # 12. Add Evidence Reference to Report
        ref_payload = {
            "external_evidence_id": "101",
            "evidence_type": "IMAGE",
            "source": "FIELD_AGENT",
        }
        res_ref = client.post(f"/reports/{report_id}/evidence", json=ref_payload)
        assert res_ref.status_code == 201

        # 13. Query Report Aggregation
        res_agg = client.get(f"/reports/{report_id}/aggregation")
        assert res_agg.status_code == 200
        agg_data = res_agg.json()
        assert agg_data["report_id"] == report_id
        assert agg_data["project_id"] == project_id
        assert agg_data["inspection"]["id"] == inspection_id
        assert "101" in agg_data["evidence"]["project_evidence_ids"]

        # 14. Verify DB Consistency: Project has dependent records so deletion is blocked
        res_del = client.delete(f"/projects/{project_id}")
        assert res_del.status_code == 409
        assert "dependent records" in res_del.json()["detail"]
    finally:
        db.close()
