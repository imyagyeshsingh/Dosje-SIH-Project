from datetime import datetime
from decimal import Decimal
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.ai_detection import AIDetection
from app.models.alert import Alert
from app.models.attendance import Attendance
from app.models.camera import Camera
from app.models.inspection import Inspection
from app.models.inspector import Inspector
from app.models.notification import Notification
from app.models.project import Project
from app.services.alert_service import generate_project_alerts


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


def create_project(session, progress: Decimal = Decimal("50")) -> Project:
    project = Project(
        project_name="Project A",
        project_code=f"NOTIF-{uuid4().hex[:8].upper()}",
        status="ACTIVE",
        progress=progress,
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def create_camera(session, project_id: int, status: str = "ACTIVE") -> Camera:
    camera = Camera(
        project_id=project_id,
        camera_name="Main Camera",
        stream_url="rtsp://example/stream",
        status=status,
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
        activity="SUSPICIOUS",
        confidence=Decimal("0.95"),
        timestamp=datetime(2026, 9, 22, 5, 0, 0),
    )
    session.add(detection)
    session.commit()
    session.refresh(detection)
    return detection


def create_attendance(session, project_id: int, expected_workers: int = 20) -> Attendance:
    attendance = Attendance(project_id=project_id, expected_workers=expected_workers)
    session.add(attendance)
    session.commit()
    session.refresh(attendance)
    return attendance


def create_alert(session, project_id: int) -> Alert:
    alert = Alert(
        project_id=project_id,
        alert_type="RISK",
        severity="HIGH",
        message="Project risk level is HIGH",
        status="OPEN",
        source="RISK_ENGINE",
    )
    session.add(alert)
    session.commit()
    session.refresh(alert)
    return alert


def create_inspection(
    session,
    project_id: int,
    *,
    status: str = "PENDING",
    officer_id: str | None = None,
    officer_name: str | None = None,
) -> Inspection:
    inspection = Inspection(
        project_id=project_id,
        inspection_type="MANUAL",
        status=status,
        officer_id=officer_id,
        officer_name=officer_name,
        assignment_status="ASSIGNED" if officer_id else "UNASSIGNED",
    )
    session.add(inspection)
    session.commit()
    session.refresh(inspection)
    return inspection


def create_inspector(session, inspector_id: str, inspector_name: str) -> Inspector:
    inspector = Inspector(
        inspector_id=inspector_id, inspector_name=inspector_name, is_active=True
    )
    session.add(inspector)
    session.commit()
    session.refresh(inspector)
    return inspector


def project_notifications(session, project_id: int) -> list[Notification]:
    statement = (
        select(Notification)
        .where(Notification.project_id == project_id)
        .order_by(Notification.id.asc())
    )
    return list(session.scalars(statement).all())


def test_generated_alert_creates_notification(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db, progress=Decimal("0"))
        camera = create_camera(db, project.id)
        create_detection(db, project.id, camera.id)

        alerts = generate_project_alerts(project.id, db)

        notifications = project_notifications(db, project.id)
        assert len(alerts) >= 1
        assert len(notifications) == len(alerts)
        assert {notification.alert_id for notification in notifications} == {
            alert.id for alert in alerts
        }
        assert all(n.notification_type == "ALERT" for n in notifications)
        assert all(n.source == "ALERT_ENGINE" for n in notifications)
        assert all(n.is_read is False for n in notifications)
        assert all(n.read_at is None for n in notifications)
        assert all(n.recipient_id is None for n in notifications)
    finally:
        db.close()


def test_generated_alert_notification_mirrors_alert_details(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db, progress=Decimal("0"))
        camera = create_camera(db, project.id)
        create_detection(db, project.id, camera.id)

        alerts = generate_project_alerts(project.id, db)
        notifications = project_notifications(db, project.id)

        by_alert_id = {notification.alert_id: notification for notification in notifications}
        for alert in alerts:
            notification = by_alert_id[alert.id]
            assert notification.message == alert.message
            assert notification.severity == alert.severity
            assert notification.title == f"{alert.alert_type} alert"
            assert notification.project_id == project.id
    finally:
        db.close()


def test_repeated_generation_does_not_create_duplicate_notifications(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db, progress=Decimal("90"))
        camera = create_camera(db, project.id)
        create_detection(db, project.id, camera.id)
        create_attendance(db, project.id, expected_workers=10)

        first_run = generate_project_alerts(project.id, db)
        count_after_first_run = db.query(Notification).count()

        second_run = generate_project_alerts(project.id, db)

        assert len(first_run) >= 1
        assert count_after_first_run >= 1
        assert second_run == []
        assert db.query(Notification).count() == count_after_first_run
    finally:
        db.close()


def test_resolved_alert_regeneration_creates_new_notification(client_and_db):
    _, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db, progress=Decimal("90"))
        camera = create_camera(db, project.id)
        create_detection(db, project.id, camera.id)

        first_run = generate_project_alerts(project.id, db)
        count_after_first_run = db.query(Notification).count()
        assert len(first_run) >= 1

        existing = db.query(Alert).filter_by(project_id=project.id, alert_type="AI_ACTIVITY").first()
        existing.status = "RESOLVED"
        db.commit()

        third_run = generate_project_alerts(project.id, db)

        assert any(alert.alert_type == "AI_ACTIVITY" for alert in third_run)
        assert db.query(Notification).count() == count_after_first_run + 1
    finally:
        db.close()


def test_generate_alerts_endpoint_creates_notification(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db, progress=Decimal("0"))
        camera = create_camera(db, project.id)
        create_detection(db, project.id, camera.id)

        response = client.post(f"/alerts/generate/{project.id}")

        assert response.status_code == 200
        generated_alerts = response.json()
        assert len(generated_alerts) >= 1

        notifications_response = client.get(f"/notifications/project/{project.id}")
        assert notifications_response.status_code == 200
        notifications = notifications_response.json()
        assert {item["alert_id"] for item in notifications} == {
            alert["id"] for alert in generated_alerts
        }
        assert all(item["notification_type"] == "ALERT" for item in notifications)
    finally:
        db.close()


def test_inspection_creation_creates_notification_with_recipient_context(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        create_inspector(db, inspector_id="OFF-77", inspector_name="Inspector Seventy Seven")

        response = client.post(
            "/inspections",
            json={
                "project_id": project.id,
                "inspection_type": "MANUAL",
                "status": "PENDING",
                "officer_id": "OFF-77",
                "officer_name": "Inspector Seventy Seven",
            },
        )

        assert response.status_code == 201
        inspection_id = response.json()["id"]

        notifications = project_notifications(db, project.id)
        assert len(notifications) == 1
        notification = notifications[0]
        assert notification.notification_type == "INSPECTION"
        assert notification.source == "INSPECTION_ENGINE"
        assert notification.inspection_id == inspection_id
        assert notification.recipient_id == "OFF-77"
        assert notification.severity == "LOW"
        assert notification.message == "New MANUAL inspection created"
        assert notification.is_read is False
    finally:
        db.close()


def test_inspection_creation_without_recipient_keeps_null_recipient(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)

        response = client.post(
            "/inspections",
            json={
                "project_id": project.id,
                "inspection_type": "SCHEDULED",
                "status": "PENDING",
            },
        )

        assert response.status_code == 201
        notifications = project_notifications(db, project.id)
        assert len(notifications) == 1
        assert notifications[0].recipient_id is None
        assert notifications[0].severity == "LOW"
    finally:
        db.close()


def test_random_inspection_creation_creates_notification(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)

        response = client.post("/inspections/random")

        assert response.status_code == 201
        inspection_id = response.json()["id"]
        notifications = project_notifications(db, project.id)
        assert len(notifications) == 1
        assert notifications[0].inspection_id == inspection_id
        assert notifications[0].notification_type == "INSPECTION"
        assert notifications[0].severity == "MEDIUM"
        assert notifications[0].recipient_id is None
        assert notifications[0].message == "New RANDOM inspection created"
    finally:
        db.close()


def test_alert_triggered_inspection_creation_creates_notification(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        alert = create_alert(db, project.id)

        response = client.post(f"/inspections/from-alert/{alert.id}")

        assert response.status_code == 201
        inspection_id = response.json()["id"]
        notifications = project_notifications(db, project.id)
        assert len(notifications) == 1
        notification = notifications[0]
        assert notification.inspection_id == inspection_id
        assert notification.notification_type == "INSPECTION"
        assert notification.severity == "HIGH"
        assert notification.recipient_id is None
        assert notification.message == "New ALERT_TRIGGERED inspection created"
    finally:
        db.close()


def test_manual_assignment_creates_notification(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        create_inspector(db, inspector_id="OFF-1001", inspector_name="Inspector Jane")
        inspection = create_inspection(db, project.id)

        response = client.post(
            f"/inspections/{inspection.id}/assign",
            json={"inspector_id": "OFF-1001", "inspector_name": "Inspector Jane"},
        )

        assert response.status_code == 200
        notifications = project_notifications(db, project.id)
        assert len(notifications) == 1
        notification = notifications[0]
        assert notification.notification_type == "ASSIGNMENT"
        assert notification.source == "ASSIGNMENT_ENGINE"
        assert notification.recipient_id == "OFF-1001"
        assert notification.severity == "MEDIUM"
        assert notification.inspection_id == inspection.id
        assert notification.message == "Inspection assigned to Inspector Jane"
        assert notification.is_read is False
    finally:
        db.close()


def test_reassignment_creates_notification_for_new_inspector(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        create_inspector(db, inspector_id="OFF-1", inspector_name="Inspector One")
        create_inspector(db, inspector_id="OFF-2", inspector_name="Inspector Two")
        inspection = create_inspection(db, project.id)

        client.post(
            f"/inspections/{inspection.id}/assign",
            json={"inspector_id": "OFF-1", "inspector_name": "Inspector One"},
        )
        client.post(
            f"/inspections/{inspection.id}/assign",
            json={"inspector_id": "OFF-2", "inspector_name": "Inspector Two"},
        )

        notifications = project_notifications(db, project.id)
        assert len(notifications) == 2
        assert [notification.recipient_id for notification in notifications] == [
            "OFF-1",
            "OFF-2",
        ]
    finally:
        db.close()


def test_repeated_same_assignment_does_not_duplicate_notification(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        create_inspector(db, inspector_id="OFF-1", inspector_name="Inspector One")
        inspection = create_inspection(db, project.id)
        payload = {"inspector_id": "OFF-1", "inspector_name": "Inspector One"}

        first = client.post(f"/inspections/{inspection.id}/assign", json=payload)
        second = client.post(f"/inspections/{inspection.id}/assign", json=payload)

        assert first.status_code == 200
        assert second.status_code == 200
        assert len(project_notifications(db, project.id)) == 1
    finally:
        db.close()


def test_unassignment_does_not_create_assignment_notification(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        create_inspector(db, inspector_id="OFF-1", inspector_name="Inspector One")
        create_inspector(db, inspector_id="OFF-2", inspector_name="Inspector Two")
        inspection = create_inspection(db, project.id)

        client.post(
            f"/inspections/{inspection.id}/assign",
            json={"inspector_id": "OFF-1", "inspector_name": "Inspector One"},
        )
        response = client.post(
            f"/inspections/{inspection.id}/assign",
            json={
                "inspector_id": "OFF-2",
                "inspector_name": "Inspector Two",
                "assignment_status": "UNASSIGNED",
            },
        )

        assert response.status_code == 200
        assert response.json()["assignment_status"] == "UNASSIGNED"
        notifications = project_notifications(db, project.id)
        assert len(notifications) == 1
        assert notifications[0].recipient_id == "OFF-1"
    finally:
        db.close()


def test_random_assignment_creates_notification(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)
        create_inspector(db, "INS-111", "Active One")
        create_inspector(db, "INS-222", "Active Two")

        monkeypatch.setattr("app.routers.inspections.random.choice", lambda values: values[1])

        response = client.post(f"/inspections/{inspection.id}/assign-random")

        assert response.status_code == 200
        assert response.json()["officer_id"] == "INS-222"

        notifications = project_notifications(db, project.id)
        assert len(notifications) == 1
        notification = notifications[0]
        assert notification.notification_type == "ASSIGNMENT"
        assert notification.recipient_id == "INS-222"
        assert notification.inspection_id == inspection.id
        assert notification.message == "Inspection randomly assigned to Active Two"
    finally:
        db.close()


def test_status_change_to_completed_creates_notification(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(
            db,
            project.id,
            status="IN_PROGRESS",
            officer_id="OFF-5",
            officer_name="Inspector Five",
        )

        response = client.put(
            f"/inspections/{inspection.id}/status", json={"status": "COMPLETED"}
        )

        assert response.status_code == 200
        notifications = project_notifications(db, project.id)
        assert len(notifications) == 1
        notification = notifications[0]
        assert notification.notification_type == "INSPECTION"
        assert notification.source == "INSPECTION_ENGINE"
        assert notification.inspection_id == inspection.id
        assert notification.recipient_id == "OFF-5"
        assert notification.severity == "LOW"
        assert notification.title == "Inspection COMPLETED"
        assert notification.message == "Inspection status changed from IN_PROGRESS to COMPLETED"
    finally:
        db.close()


def test_status_change_to_cancelled_creates_notification(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id, status="PENDING")

        response = client.put(
            f"/inspections/{inspection.id}/status", json={"status": "CANCELLED"}
        )

        assert response.status_code == 200
        notifications = project_notifications(db, project.id)
        assert len(notifications) == 1
        assert notifications[0].severity == "MEDIUM"
        assert notifications[0].message == "Inspection status changed from PENDING to CANCELLED"
        assert notifications[0].recipient_id is None
    finally:
        db.close()


def test_status_change_to_in_progress_does_not_create_notification(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id, status="PENDING")

        response = client.put(
            f"/inspections/{inspection.id}/status", json={"status": "IN_PROGRESS"}
        )

        assert response.status_code == 200
        assert response.json()["started_at"] is not None
        assert project_notifications(db, project.id) == []
    finally:
        db.close()


def test_generic_update_status_change_creates_notification(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(
            db,
            project.id,
            status="PENDING",
            officer_id="OFF-9",
            officer_name="Inspector Nine",
        )

        response = client.put(
            f"/inspections/{inspection.id}",
            json={"status": "CANCELLED", "reason": "Site closed"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "CANCELLED"
        assert data["reason"] == "Site closed"

        notifications = project_notifications(db, project.id)
        assert len(notifications) == 1
        assert notifications[0].message == "Inspection status changed from PENDING to CANCELLED"
        assert notifications[0].recipient_id == "OFF-9"
    finally:
        db.close()


def test_generic_update_without_status_change_creates_no_notification(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id)

        response = client.put(f"/inspections/{inspection.id}", json={"findings": "Nothing found"})

        assert response.status_code == 200
        assert project_notifications(db, project.id) == []
    finally:
        db.close()


def test_invalid_status_transition_is_rejected_without_notification(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        inspection = create_inspection(db, project.id, status="COMPLETED", officer_id="OFF-3")

        response = client.put(
            f"/inspections/{inspection.id}/status", json={"status": "IN_PROGRESS"}
        )

        assert response.status_code == 400
        assert project_notifications(db, project.id) == []
    finally:
        db.close()


def test_existing_inspection_lifecycle_remains_intact(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        create_inspector(db, inspector_id="OFF-55", inspector_name="Inspector Fifty Five")

        created = client.post(
            "/inspections",
            json={
                "project_id": project.id,
                "inspection_type": "MANUAL",
                "status": "PENDING",
            },
        )
        assert created.status_code == 201
        inspection_id = created.json()["id"]

        assigned = client.post(
            f"/inspections/{inspection_id}/assign",
            json={"inspector_id": "OFF-55", "inspector_name": "Inspector Fifty Five"},
        )
        assert assigned.status_code == 200
        assert assigned.json()["assigned_at"] is not None
        assert assigned.json()["assignment_status"] == "ASSIGNED"

        started = client.put(
            f"/inspections/{inspection_id}/status", json={"status": "IN_PROGRESS"}
        )
        assert started.status_code == 200
        assert started.json()["started_at"] is not None

        completed = client.put(
            f"/inspections/{inspection_id}/status", json={"status": "COMPLETED"}
        )
        assert completed.status_code == 200
        assert completed.json()["completed_at"] is not None

        rejected = client.put(
            f"/inspections/{inspection_id}/status", json={"status": "IN_PROGRESS"}
        )
        assert rejected.status_code == 400

        fetched = client.get(f"/inspections/{inspection_id}")
        assert fetched.status_code == 200
        assert fetched.json()["status"] == "COMPLETED"

        listed = client.get(f"/inspections/project/{project.id}")
        assert listed.status_code == 200
        assert [item["id"] for item in listed.json()] == [inspection_id]

        notifications = project_notifications(db, project.id)
        assert len(notifications) == 3
        assert [notification.notification_type for notification in notifications] == [
            "INSPECTION",
            "ASSIGNMENT",
            "INSPECTION",
        ]
        assert notifications[0].recipient_id is None
        assert notifications[1].recipient_id == "OFF-55"
        assert (
            notifications[2].message
            == "Inspection status changed from IN_PROGRESS to COMPLETED"
        )
        assert notifications[2].recipient_id == "OFF-55"
    finally:
        db.close()
