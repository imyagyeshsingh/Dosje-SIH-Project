import random
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.alert import Alert
from app.models.audit_log import AuditLog
from app.models.inspection import Inspection
from app.models.inspector import Inspector
from app.models.media import Media
from app.models.notification import Notification
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


def create_project(session, project_name: str = "Project A") -> Project:
    project = Project(
        project_name=project_name,
        project_code=f"INS-{project_name.lower().replace(' ', '-')}-{datetime.now(timezone.utc).timestamp()}",
        status="ACTIVE",
        progress=50,
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def create_inspector(session, inspector_id="INS-100", inspector_name="Inspector Jane", is_active=True):
    inspector = Inspector(
        inspector_id=inspector_id,
        inspector_name=inspector_name,
        is_active=is_active,
    )
    session.add(inspector)
    session.commit()
    session.refresh(inspector)
    return inspector


def test_create_inspection_success(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        payload = {
            "project_id": project.id,
            "inspection_type": "RANDOM",
            "status": "PENDING",
            "officer_name": "Jane Officer",
            "reason": "Routine check",
        }

        response = client.post("/inspections", json=payload)

        assert response.status_code == 201
        data = response.json()
        assert data["project_id"] == project.id
        assert data["inspection_type"] == "RANDOM"
        assert data["status"] == "PENDING"
        assert data["officer_name"] == "Jane Officer"

        audit_logs = db.query(AuditLog).filter(
            AuditLog.project_id == project.id,
            AuditLog.entity_type == "INSPECTION",
            AuditLog.entity_id == data["id"],
            AuditLog.action == "CREATED",
        ).all()
        assert len(audit_logs) == 1
        assert audit_logs[0].actor_name == "Jane Officer"
        assert db.query(Notification).filter(Notification.inspection_id == data["id"]).count() == 1
    finally:
        db.close()


def test_create_inspection_for_missing_project_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.post(
        "/inspections",
        json={"project_id": 999, "inspection_type": "MANUAL", "status": "PENDING"},
    )
    assert response.status_code == 404


def test_create_accepts_all_inspection_types(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        for inspection_type in ["RANDOM", "ALERT_TRIGGERED", "SCHEDULED", "MANUAL"]:
            response = client.post(
                "/inspections",
                json={"project_id": project.id, "inspection_type": inspection_type, "status": "PENDING"},
            )
            assert response.status_code == 201
            assert response.json()["inspection_type"] == inspection_type
    finally:
        db.close()


def test_get_inspection_by_id(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(
            project_id=project.id,
            inspection_type="SCHEDULED",
            status="SCHEDULED",
            officer_name="Officer Lee",
        )
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.get(f"/inspections/{inspection.id}")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == inspection.id
        assert data["inspection_type"] == "SCHEDULED"
    finally:
        db.close()


def test_get_inspection_missing_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.get("/inspections/999")
    assert response.status_code == 404


def test_list_project_inspections(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db, "Project A")
        other_project = create_project(db, "Project B")

        first = Inspection(project_id=project.id, inspection_type="RANDOM", status="PENDING")
        second = Inspection(project_id=project.id, inspection_type="ALERT_TRIGGERED", status="IN_PROGRESS")
        third = Inspection(project_id=other_project.id, inspection_type="MANUAL", status="PENDING")
        db.add_all([first, second, third])
        db.commit()
        db.refresh(first)
        db.refresh(second)
        db.refresh(third)

        response = client.get(f"/inspections/project/{project.id}")

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2
        assert [item["id"] for item in data] == [second.id, first.id]
        assert all(item["project_id"] == project.id for item in data)
    finally:
        db.close()


def test_project_list_with_no_inspections_returns_empty_list(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.get(f"/inspections/project/{project.id}")
        assert response.status_code == 200
        assert response.json() == []
    finally:
        db.close()


def test_list_project_inspections_missing_project_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.get("/inspections/project/999")
    assert response.status_code == 404


def test_project_inspection_isolation(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")
        inspection_a = Inspection(project_id=project_a.id, inspection_type="MANUAL", status="PENDING")
        inspection_b = Inspection(project_id=project_b.id, inspection_type="SCHEDULED", status="PENDING")
        db.add_all([inspection_a, inspection_b])
        db.commit()

        response = client.get(f"/inspections/project/{project_a.id}")

        assert response.status_code == 200
        ids = [item["id"] for item in response.json()]
        assert inspection_a.id in ids
        assert inspection_b.id not in ids
    finally:
        db.close()


def test_update_inspection_success(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(
            project_id=project.id,
            inspection_type="RANDOM",
            status="PENDING",
            reason="First reason",
        )
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.put(
            f"/inspections/{inspection.id}",
            json={"status": "IN_PROGRESS", "officer_name": "Updated Officer", "reason": "Updated reason"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "IN_PROGRESS"
        assert data["officer_name"] == "Updated Officer"
        assert data["reason"] == "Updated reason"

        audit_logs = db.query(AuditLog).filter(
            AuditLog.project_id == project.id,
            AuditLog.entity_type == "INSPECTION",
            AuditLog.entity_id == inspection.id,
            AuditLog.action == "STATUS_CHANGED",
        ).all()
        assert len(audit_logs) == 1
        assert "PENDING" in audit_logs[0].details
        assert "IN_PROGRESS" in audit_logs[0].details
    finally:
        db.close()


def test_update_inspection_status_unchanged_does_not_create_status_audit(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.put(f"/inspections/{inspection.id}/status", json={"status": "PENDING"})

        assert response.status_code == 400
        audit_count = db.query(AuditLog).filter(
            AuditLog.project_id == project.id,
            AuditLog.entity_type == "INSPECTION",
            AuditLog.entity_id == inspection.id,
            AuditLog.action == "STATUS_CHANGED",
        ).count()
        assert audit_count == 0
    finally:
        db.close()


def test_update_missing_inspection_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.put("/inspections/999", json={"status": "COMPLETED"})
    assert response.status_code == 404


def test_create_random_inspection_success(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")
        project_c = create_project(db, "Project C")
        monkeypatch.setattr(random, "choice", lambda items: project_b.id if items == [project_a.id, project_b.id, project_c.id] else items[0])

        response = client.post("/inspections/random")

        assert response.status_code == 201
        data = response.json()
        assert data["inspection_type"] == "RANDOM"
        assert data["status"] == "PENDING"
        assert data["project_id"] in {project_a.id, project_b.id, project_c.id}
    finally:
        db.close()


def test_random_inspection_excludes_active_projects(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        active_project = create_project(db, "Active")
        completed_project = create_project(db, "Completed")
        cancelled_project = create_project(db, "Cancelled")
        eligible_project = create_project(db, "Eligible")

        db.add_all(
            [
                Inspection(project_id=active_project.id, inspection_type="RANDOM", status="PENDING"),
                Inspection(project_id=completed_project.id, inspection_type="RANDOM", status="COMPLETED"),
                Inspection(project_id=cancelled_project.id, inspection_type="MANUAL", status="CANCELLED"),
            ]
        )
        db.commit()

        response = client.post("/inspections/random")

        assert response.status_code == 201
        data = response.json()
        assert data["project_id"] in {eligible_project.id, completed_project.id, cancelled_project.id}
        assert data["project_id"] != active_project.id
    finally:
        db.close()


def test_random_inspection_requires_eligible_projects(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")

        db.add_all(
            [
                Inspection(project_id=project_a.id, inspection_type="RANDOM", status="PENDING"),
                Inspection(project_id=project_b.id, inspection_type="SCHEDULED", status="IN_PROGRESS"),
            ]
        )
        db.commit()

        before_count = db.scalar(select(func.count()).select_from(Inspection))
        response = client.post("/inspections/random")

        assert response.status_code == 404
        assert response.json()["detail"] == "No eligible project available for random inspection"
        assert db.scalar(select(func.count()).select_from(Inspection)) == before_count
    finally:
        db.close()


def test_random_inspection_selects_only_one_eligible_project(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")
        project_c = create_project(db, "Project C")
        monkeypatch.setattr(random, "choice", lambda items: items[0])

        first = client.post("/inspections/random")
        second = client.post("/inspections/random")

        assert first.status_code == 201
        assert second.status_code == 201
        assert first.json()["project_id"] in {project_a.id, project_b.id, project_c.id}
        assert second.json()["project_id"] in {project_a.id, project_b.id, project_c.id}
        assert first.json()["project_id"] != second.json()["project_id"]
    finally:
        db.close()


def test_valid_status_transitions(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        cases = [
            ("PENDING", "SCHEDULED"),
            ("PENDING", "IN_PROGRESS"),
            ("PENDING", "CANCELLED"),
            ("SCHEDULED", "IN_PROGRESS"),
            ("SCHEDULED", "CANCELLED"),
            ("IN_PROGRESS", "COMPLETED"),
            ("IN_PROGRESS", "CANCELLED"),
        ]

        for current_status, next_status in cases:
            inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status=current_status)
            db.add(inspection)
            db.commit()
            db.refresh(inspection)

            response = client.put(
                f"/inspections/{inspection.id}/status",
                json={"status": next_status},
            )

            assert response.status_code == 200, (current_status, next_status, response.text)
            assert response.json()["status"] == next_status
    finally:
        db.close()


def test_invalid_status_transitions_return_400(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        invalid_cases = [
            ("COMPLETED", "PENDING"),
            ("COMPLETED", "IN_PROGRESS"),
            ("CANCELLED", "PENDING"),
            ("CANCELLED", "IN_PROGRESS"),
            ("PENDING", "COMPLETED"),
            ("SCHEDULED", "COMPLETED"),
            ("SCHEDULED", "PENDING"),
            ("IN_PROGRESS", "PENDING"),
            ("IN_PROGRESS", "SCHEDULED"),
        ]

        for current_status, next_status in invalid_cases:
            inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status=current_status)
            db.add(inspection)
            db.commit()
            db.refresh(inspection)

            response = client.put(
                f"/inspections/{inspection.id}/status",
                json={"status": next_status},
            )

            assert response.status_code == 400, (current_status, next_status, response.text)
            assert response.json()["detail"] == f"Invalid inspection status transition: {current_status} -> {next_status}"
    finally:
        db.close()


def test_workflow_timestamp_behavior(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)

        pending = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(pending)
        db.commit()
        db.refresh(pending)

        response = client.put(f"/inspections/{pending.id}/status", json={"status": "IN_PROGRESS"})
        assert response.status_code == 200
        assert response.json()["started_at"] is not None

        in_progress = Inspection(
            project_id=project.id,
            inspection_type="MANUAL",
            status="IN_PROGRESS",
            started_at=datetime(2024, 1, 1, 10, 0, tzinfo=timezone.utc),
        )
        db.add(in_progress)
        db.commit()
        db.refresh(in_progress)

        response = client.put(f"/inspections/{in_progress.id}/status", json={"status": "COMPLETED"})
        assert response.status_code == 200
        assert response.json()["completed_at"] is not None
        assert response.json()["started_at"] == "2024-01-01T10:00:00"

        cancelled = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(cancelled)
        db.commit()
        db.refresh(cancelled)

        response = client.put(f"/inspections/{cancelled.id}/status", json={"status": "CANCELLED"})
        assert response.status_code == 200
        assert response.json()["completed_at"] is None
    finally:
        db.close()


def test_general_update_cannot_bypass_workflow_rules(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.put(
            f"/inspections/{inspection.id}",
            json={"status": "COMPLETED", "reason": "Attempted bypass"},
        )

        assert response.status_code == 400
        assert response.json()["detail"] == "Invalid inspection status transition: PENDING -> COMPLETED"

        refreshed = client.get(f"/inspections/{inspection.id}")
        assert refreshed.json()["status"] == "PENDING"
    finally:
        db.close()


def test_invalid_status_value_is_rejected_by_schema(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.put(
            f"/inspections/{inspection.id}/status",
            json={"status": "INVALID"},
        )

        assert response.status_code == 422
    finally:
        db.close()


def test_missing_inspection_status_update_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.put("/inspections/999/status", json={"status": "SCHEDULED"})
    assert response.status_code == 404


def test_alert_triggered_inspection_creates_from_alert(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        alert = Alert(
            project_id=project.id,
            alert_type="RISK",
            severity="HIGH",
            message="Risk level is HIGH",
            status="OPEN",
            source="RISK_ENGINE",
        )
        db.add(alert)
        db.commit()
        db.refresh(alert)

        response = client.post(f"/inspections/from-alert/{alert.id}")

        assert response.status_code == 201
        data = response.json()
        assert data["inspection_type"] == "ALERT_TRIGGERED"
        assert data["status"] == "PENDING"
        assert data["project_id"] == project.id
        assert data["alert_id"] == alert.id
        assert data["reason"] == "Inspection triggered by alert: Risk level is HIGH"
    finally:
        db.close()


def test_alert_triggered_inspection_missing_alert_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.post("/inspections/from-alert/999")
    assert response.status_code == 404


def test_alert_triggered_inspection_blocks_active_project_inspections(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        active_statuses = ["PENDING", "SCHEDULED", "IN_PROGRESS"]
        for status in active_statuses:
            alert = Alert(
                project_id=project.id,
                alert_type="RISK",
                severity="HIGH",
                message=f"Alert for {status}",
                status="OPEN",
                source="RISK_ENGINE",
            )
            db.add(alert)
            db.commit()
            db.refresh(alert)

            db.add(Inspection(project_id=project.id, inspection_type="MANUAL", status=status))
            db.commit()

            response = client.post(f"/inspections/from-alert/{alert.id}")
            assert response.status_code == 400
            assert response.json()["detail"] == "Project already has an active inspection"

        completed_project = create_project(db, "Completed Project")
        completed_alert = Alert(
            project_id=completed_project.id,
            alert_type="RISK",
            severity="HIGH",
            message="Completed alert",
            status="OPEN",
            source="RISK_ENGINE",
        )
        db.add(completed_alert)
        db.commit()
        db.refresh(completed_alert)

        db.add(Inspection(project_id=completed_project.id, inspection_type="MANUAL", status="COMPLETED"))
        db.commit()

        response = client.post(f"/inspections/from-alert/{completed_alert.id}")
        assert response.status_code == 201
        assert response.json()["inspection_type"] == "ALERT_TRIGGERED"
    finally:
        db.close()


def test_alert_triggered_inspection_project_isolation(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")

        alert = Alert(
            project_id=project_a.id,
            alert_type="RISK",
            severity="HIGH",
            message="Project A alert",
            status="OPEN",
            source="RISK_ENGINE",
        )
        db.add(alert)
        db.commit()
        db.refresh(alert)

        response = client.post(f"/inspections/from-alert/{alert.id}")

        assert response.status_code == 201
        data = response.json()
        assert data["project_id"] == project_a.id
        assert data["project_id"] != project_b.id
    finally:
        db.close()


def test_assign_inspector_to_inspection_success(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        create_inspector(db, inspector_id="OFF-1001", inspector_name="Inspector Jane")
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.post(
            f"/inspections/{inspection.id}/assign",
            json={"inspector_id": "OFF-1001", "inspector_name": "Inspector Jane"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == inspection.id
        assert data["officer_id"] == "OFF-1001"
        assert data["officer_name"] == "Inspector Jane"
        assert data["assignment_status"] == "ASSIGNED"
        assert data["assigned_at"] is not None

        audit_logs = db.query(AuditLog).filter(
            AuditLog.project_id == project.id,
            AuditLog.entity_type == "INSPECTION",
            AuditLog.entity_id == inspection.id,
            AuditLog.action == "ASSIGNED",
        ).all()
        assert len(audit_logs) == 1
        assert audit_logs[0].actor_id == "OFF-1001"
        assert db.query(Notification).filter(Notification.inspection_id == inspection.id).count() == 1
    finally:
        db.close()


def test_get_inspection_assignment_returns_current_assignment(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(
            project_id=project.id,
            inspection_type="SCHEDULED",
            status="SCHEDULED",
            officer_id="OFF-42",
            officer_name="Inspector Smith",
            assignment_status="ASSIGNED",
            assigned_at=datetime(2026, 9, 22, 11, 0, tzinfo=timezone.utc),
        )
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.get(f"/inspections/{inspection.id}/assignment")

        assert response.status_code == 200
        data = response.json()
        assert data["inspection_id"] == inspection.id
        assert data["inspector_id"] == "OFF-42"
        assert data["inspector_name"] == "Inspector Smith"
        assert data["assignment_status"] == "ASSIGNED"
    finally:
        db.close()


def test_assign_inspector_missing_inspection_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.post("/inspections/999/assign", json={"inspector_id": "OFF-99"})
    assert response.status_code == 404


def test_assign_inspector_with_invalid_data_is_rejected(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        invalid_payloads = [
            {"inspector_name": "Inspector Jane"},
            {"inspector_id": "   ", "inspector_name": "Inspector Jane"},
            {"inspector_id": "OFF-1", "assignment_status": "INVALID"},
        ]

        for payload in invalid_payloads:
            response = client.post(f"/inspections/{inspection.id}/assign", json=payload)
            assert response.status_code in {400, 422}, payload
    finally:
        db.close()


def test_assign_inspector_reassigns_deteministically(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        create_inspector(db, inspector_id="OFF-1001", inspector_name="Inspector Jane")
        create_inspector(db, inspector_id="OFF-2002", inspector_name="Inspector Bob")
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        first = client.post(
            f"/inspections/{inspection.id}/assign",
            json={"inspector_id": "OFF-1001", "inspector_name": "Inspector Jane"},
        )
        second = client.post(
            f"/inspections/{inspection.id}/assign",
            json={"inspector_id": "OFF-1001", "inspector_name": "Inspector Jane"},
        )
        third = client.post(
            f"/inspections/{inspection.id}/assign",
            json={"inspector_id": "OFF-2002", "inspector_name": "Inspector Bob"},
        )

        assert first.status_code == 200
        assert second.status_code == 200
        assert third.status_code == 200
        assert first.json()["officer_id"] == "OFF-1001"
        assert second.json()["officer_id"] == "OFF-1001"
        assert third.json()["officer_id"] == "OFF-2002"
        assert third.json()["officer_name"] == "Inspector Bob"
    finally:
        db.close()


def test_assignment_respects_inspection_lifecycle_rules(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        completed = Inspection(project_id=project.id, inspection_type="MANUAL", status="COMPLETED")
        cancelled = Inspection(project_id=project.id, inspection_type="MANUAL", status="CANCELLED")
        db.add_all([completed, cancelled])
        db.commit()
        db.refresh(completed)
        db.refresh(cancelled)

        for inspection in (completed, cancelled):
            response = client.post(
                f"/inspections/{inspection.id}/assign",
                json={"inspector_id": "OFF-777", "inspector_name": "Inspector Locked"},
            )
            assert response.status_code == 400
            assert "not assignable" in response.json()["detail"]
    finally:
        db.close()


def test_submit_inspection_location_success(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        project.latitude = 12.9716
        project.longitude = 77.5946
        db.commit()

        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.post(
            f"/inspections/{inspection.id}/location",
            json={"latitude": 12.9717, "longitude": 77.5947, "location_accuracy": 5.0},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["inspection_id"] == inspection.id
        assert data["inspection_latitude"] == 12.9717
        assert data["inspection_longitude"] == 77.5947
        assert data["location_verified"] is True
        assert data["distance_from_project"] is not None
    finally:
        db.close()


def test_submit_inspection_location_outside_radius_is_unverified(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        project.latitude = 12.9716
        project.longitude = 77.5946
        db.commit()

        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.post(
            f"/inspections/{inspection.id}/location",
            json={"latitude": 12.9728, "longitude": 77.5946},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["location_verified"] is False
        assert data["distance_from_project"] is not None
    finally:
        db.close()


def test_submit_inspection_location_invalid_latitude(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        project.latitude = 12.9716
        project.longitude = 77.5946
        db.commit()

        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.post(
            f"/inspections/{inspection.id}/location",
            json={"latitude": 91, "longitude": 77.5946},
        )

        assert response.status_code == 422
    finally:
        db.close()


def test_submit_inspection_location_invalid_longitude(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        project.latitude = 12.9716
        project.longitude = 77.5946
        db.commit()

        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.post(
            f"/inspections/{inspection.id}/location",
            json={"latitude": 12.9716, "longitude": 181},
        )

        assert response.status_code == 422
    finally:
        db.close()


def test_submit_inspection_location_missing_inspection_returns_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        project.latitude = 12.9716
        project.longitude = 77.5946
        db.commit()

        response = client.post(
            "/inspections/999/location",
            json={"latitude": 12.9717, "longitude": 77.5947},
        )

        assert response.status_code == 404
    finally:
        db.close()


def test_submit_inspection_location_project_without_coordinates_returns_400(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.post(
            f"/inspections/{inspection.id}/location",
            json={"latitude": 12.9717, "longitude": 77.5947},
        )

        assert response.status_code == 400
        assert "GPS coordinates" in response.json()["detail"]
    finally:
        db.close()


def test_get_inspection_location_returns_none_when_unsubmitted(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        project.latitude = 12.9716
        project.longitude = 77.5946
        db.commit()

        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.get(f"/inspections/{inspection.id}/location")

        assert response.status_code == 200
        data = response.json()
        assert data["inspection_latitude"] is None
        assert data["inspection_longitude"] is None
        assert data["location_verified"] is False
        assert data["distance_from_project"] is None
    finally:
        db.close()


def test_submit_inspection_evidence_photo_success(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        def fake_upload(file_obj, filename, project_id, inspection_id, content_type, file_size):
            return {
                "storage_provider": "cloudinary",
                "media_type": "IMAGE",
                "source_type": "MANUAL_UPLOAD",
                "storage_public_id": "project-1-evidence-photo",
                "media_url": "https://res.cloudinary.com/demo/photo.jpg",
                "original_filename": filename,
                "mime_type": "image/jpeg",
                "file_size": 1024,
            }

        monkeypatch.setattr("app.routers.inspections.upload_media_to_cloudinary", fake_upload)

        response = client.post(
            f"/inspections/{inspection.id}/evidence",
            files={"file": ("photo.jpg", b"image-bytes", "image/jpeg")},
            data={
                "description": "Front gate photo",
                "captured_at": "2026-09-22T09:00:00+00:00",
                "latitude": "12.9717",
                "longitude": "77.5947",
                "location_accuracy": "5.0",
            },
        )

        assert response.status_code == 201
        data = response.json()
        assert data["inspection_id"] == inspection.id
        assert data["media_type"] == "IMAGE"
        assert data["latitude"] == 12.9717
        assert data["longitude"] == 77.5947
        assert data["description"] == "Front gate photo"
        assert db.query(Media).filter(Media.inspection_id == inspection.id).count() == 1
    finally:
        db.close()


def test_submit_inspection_evidence_video_success(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        def fake_upload(file_obj, filename, project_id, inspection_id, content_type, file_size):
            return {
                "storage_provider": "cloudinary",
                "media_type": "VIDEO",
                "source_type": "MANUAL_UPLOAD",
                "storage_public_id": "project-1-evidence-video",
                "media_url": "https://res.cloudinary.com/demo/video.mp4",
                "original_filename": filename,
                "mime_type": "video/mp4",
                "file_size": 4096,
            }

        monkeypatch.setattr("app.routers.inspections.upload_media_to_cloudinary", fake_upload)
        response = client.post(
            f"/inspections/{inspection.id}/evidence",
            files={"file": ("clip.mp4", b"video-bytes", "video/mp4")},
            data={"description": "Video walk-through"},
        )

        assert response.status_code == 201
        data = response.json()
        assert data["inspection_id"] == inspection.id
        assert data["media_type"] == "VIDEO"
        assert data["description"] == "Video walk-through"
    finally:
        db.close()


def test_submit_inspection_evidence_rejects_missing_inspection(client_and_db):
    client, _ = client_and_db
    response = client.post(
        "/inspections/999/evidence",
        files={"file": ("photo.jpg", b"photo-bytes", "image/jpeg")},
    )
    assert response.status_code == 404


def test_submit_inspection_evidence_rejects_unsupported_file_type(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.post(
            f"/inspections/{inspection.id}/evidence",
            files={"file": ("demo.txt", b"text", "text/plain")},
        )

        assert response.status_code == 400
        assert "Only image and video files are supported" in response.json()["detail"]
    finally:
        db.close()


def test_submit_inspection_evidence_rejects_invalid_gps_coordinates(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.post(
            f"/inspections/{inspection.id}/evidence",
            files={"file": ("photo.jpg", b"image-bytes", "image/jpeg")},
            data={"latitude": "91", "longitude": "77.5947"},
        )

        assert response.status_code == 422
    finally:
        db.close()


def test_submit_inspection_evidence_handles_cloudinary_failure_without_persisting(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        def fake_upload(file_obj, filename, project_id, inspection_id, content_type, file_size):
            raise RuntimeError("Cloudinary unavailable")

        monkeypatch.setattr("app.routers.inspections.upload_media_to_cloudinary", fake_upload)
        response = client.post(
            f"/inspections/{inspection.id}/evidence",
            files={"file": ("photo.jpg", b"image-bytes", "image/jpeg")},
        )

        assert response.status_code == 502
        assert response.json()["detail"] == "Failed to upload media to Cloudinary"
        assert db.query(Media).count() == 0
    finally:
        db.close()


def test_get_inspection_evidence_returns_newest_first(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        def fake_upload(file_obj, filename, project_id, inspection_id, content_type, file_size):
            return {
                "storage_provider": "cloudinary",
                "media_type": "IMAGE",
                "source_type": "MANUAL_UPLOAD",
                "storage_public_id": filename,
                "media_url": f"https://res.cloudinary.com/demo/{filename}",
                "original_filename": filename,
                "mime_type": "image/jpeg",
                "file_size": 2048,
            }

        monkeypatch.setattr("app.routers.inspections.upload_media_to_cloudinary", fake_upload)
        client.post(
            f"/inspections/{inspection.id}/evidence",
            files={"file": ("first.jpg", b"a", "image/jpeg")},
        )
        client.post(
            f"/inspections/{inspection.id}/evidence",
            files={"file": ("second.jpg", b"b", "image/jpeg")},
        )

        response = client.get(f"/inspections/{inspection.id}/evidence")
        assert response.status_code == 200
        data = response.json()
        assert [item["original_filename"] for item in data] == ["second.jpg", "first.jpg"]
    finally:
        db.close()


def test_create_inspector_success(client_and_db):
    client, _ = client_and_db
    response = client.post(
        "/inspectors",
        json={"inspector_id": "INS-201", "inspector_name": "Inspector Dana", "is_active": True},
    )

    assert response.status_code == 201
    data = response.json()
    assert data["inspector_id"] == "INS-201"
    assert data["inspector_name"] == "Inspector Dana"
    assert data["is_active"] is True


def test_list_inspectors_supports_active_filter(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        create_inspector(db, "INS-1", "Active One", True)
        create_inspector(db, "INS-2", "Inactive One", False)

        active_response = client.get("/inspectors", params={"is_active": True})
        inactive_response = client.get("/inspectors", params={"is_active": False})

        assert active_response.status_code == 200
        active_ids = {item["inspector_id"] for item in active_response.json()}
        assert {"INS-1"} == active_ids
        assert inactive_response.status_code == 200
        inactive_ids = {item["inspector_id"] for item in inactive_response.json()}
        assert {"INS-2"} == inactive_ids
    finally:
        db.close()


def test_assign_random_inspector_to_inspection_requires_active_inspector(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.post(f"/inspections/{inspection.id}/assign-random")
        assert response.status_code == 404
        assert "No active inspector" in response.json()["detail"]
    finally:
        db.close()


def test_assign_random_inspector_selects_from_active_pool(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        active_one = create_inspector(db, "INS-111", "Active One", True)
        inactive = create_inspector(db, "INS-222", "Inactive One", False)
        active_two = create_inspector(db, "INS-333", "Active Two", True)

        monkeypatch.setattr("app.routers.inspections.random.choice", lambda values: values[1])

        response = client.post(f"/inspections/{inspection.id}/assign-random")

        assert response.status_code == 200
        data = response.json()
        assert data["officer_id"] == active_two.inspector_id
        assert data["officer_name"] == active_two.inspector_name
        assert data["assignment_status"] == "ASSIGNED"
        assert data["assigned_at"] is not None
        assert data["id"] == inspection.id
        assert inactive.inspector_id not in {data["officer_id"]}
        db.refresh(inspection)
        assert inspection.officer_id == active_two.inspector_id
        assert inspection.officer_name == active_two.inspector_name

        audit_logs = db.query(AuditLog).filter(
            AuditLog.project_id == project.id,
            AuditLog.entity_type == "INSPECTION",
            AuditLog.entity_id == inspection.id,
            AuditLog.action == "RANDOMLY_ASSIGNED",
        ).all()
        assert len(audit_logs) == 1
        assert audit_logs[0].actor_id == active_two.inspector_id
        assert db.query(Notification).filter(Notification.inspection_id == inspection.id).count() == 1
    finally:
        db.close()


def test_assign_random_inspector_rejects_completed_and_cancelled_inspections(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        create_inspector(db, "INS-OK", "Available Inspector", True)

        for status in ["COMPLETED", "CANCELLED"]:
            inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status=status)
            db.add(inspection)
            db.commit()
            db.refresh(inspection)

            response = client.post(f"/inspections/{inspection.id}/assign-random")
            assert response.status_code == 400
            assert "not assignable" in response.json()["detail"]
    finally:
        db.close()


def test_assign_random_inspector_missing_inspection_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.post("/inspections/999/assign-random")
    assert response.status_code == 404


def test_assign_random_inspector_ignores_inactive_inspectors(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        active = create_inspector(db, "INS-ACTIVE", "Available Inspector", True)
        create_inspector(db, "INS-INACTIVE", "Hidden Inspector", False)
        monkeypatch.setattr("app.routers.inspections.random.choice", lambda values: values[0])

        response = client.post(f"/inspections/{inspection.id}/assign-random")

        assert response.status_code == 200
        assert response.json()["officer_id"] == active.inspector_id
        assert response.json()["officer_name"] == active.inspector_name
    finally:
        db.close()


def test_manual_assignment_still_works_after_random_assignment_feature(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        create_inspector(db, inspector_id="OFF-900", inspector_name="Manual Inspector")
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.post(
            f"/inspections/{inspection.id}/assign",
            json={"inspector_id": "OFF-900", "inspector_name": "Manual Inspector"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["officer_id"] == "OFF-900"
        assert data["officer_name"] == "Manual Inspector"
        assert data["assignment_status"] == "ASSIGNED"
    finally:
        db.close()


def test_openapi_contains_inspection_routes(client_and_db):
    client, _ = client_and_db
    routes = set(client.get("/openapi.json").json()["paths"].keys())
    assert "/inspections" in routes
    assert "/inspections/random" in routes
    assert "/inspections/from-alert/{alert_id}" in routes
    assert "/inspections/{inspection_id}" in routes
    assert "/inspections/project/{project_id}" in routes
    assert "/inspections/{inspection_id}/status" in routes
    assert "/inspections/{inspection_id}/evidence" in routes
    assert "/inspectors" in routes


# --- Task 21A: inspection alert validation ---

def test_create_inspection_with_nonexistent_alert_returns_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/inspections",
            json={
                "project_id": project.id,
                "inspection_type": "MANUAL",
                "status": "PENDING",
                "alert_id": 999,
            },
        )
        assert response.status_code == 404
    finally:
        db.close()


def test_create_inspection_with_cross_project_alert_returns_400(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")
        other_alert = Alert(
            project_id=project_b.id,
            alert_type="RISK",
            severity="HIGH",
            message="Other project alert",
            status="OPEN",
            source="RISK_ENGINE",
        )
        db.add(other_alert)
        db.commit()
        db.refresh(other_alert)

        response = client.post(
            "/inspections",
            json={
                "project_id": project_a.id,
                "inspection_type": "MANUAL",
                "status": "PENDING",
                "alert_id": other_alert.id,
            },
        )
        assert response.status_code == 400
        assert "does not belong" in response.json()["detail"]
    finally:
        db.close()


def test_update_inspection_with_cross_project_alert_returns_400(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")
        other_alert = Alert(
            project_id=project_b.id,
            alert_type="RISK",
            severity="HIGH",
            message="Other project alert",
            status="OPEN",
            source="RISK_ENGINE",
        )
        db.add(other_alert)
        db.commit()
        db.refresh(other_alert)

        inspection = Inspection(
            project_id=project_a.id, inspection_type="MANUAL", status="PENDING"
        )
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.put(
            f"/inspections/{inspection.id}",
            json={"alert_id": other_alert.id},
        )
        assert response.status_code == 400
        assert "does not belong" in response.json()["detail"]
    finally:
        db.close()


def test_update_inspection_with_nonexistent_alert_returns_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(
            project_id=project.id, inspection_type="MANUAL", status="PENDING"
        )
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.put(
            f"/inspections/{inspection.id}", json={"alert_id": 999}
        )
        assert response.status_code == 404
    finally:
        db.close()


# --- Task 21A: manual inspector assignment existence check ---

def test_assign_inspector_with_nonexistent_id_returns_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        response = client.post(
            f"/inspections/{inspection.id}/assign",
            json={"inspector_id": "NONEXISTENT-INSPECTOR", "inspector_name": "Ghost"},
        )
        assert response.status_code == 404
        assert "Inspector not found" in response.json()["detail"]
    finally:
        db.close()


def test_assign_inspector_with_existing_inspector_succeeds(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        inspector = Inspector(
            inspector_id="INS-21A",
            inspector_name="Real Inspector",
            is_active=True,
        )
        db.add(inspector)
        db.commit()
        db.refresh(inspector)

        response = client.post(
            f"/inspections/{inspection.id}/assign",
            json={"inspector_id": inspector.inspector_id, "inspector_name": inspector.inspector_name},
        )
        assert response.status_code == 200
        assert response.json()["officer_id"] == inspector.inspector_id
    finally:
        db.close()
