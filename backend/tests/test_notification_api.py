from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.alert import Alert
from app.models.inspection import Inspection
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
        project_code=f"NOTIF-{uuid4().hex[:8].upper()}",
        status="ACTIVE",
        progress=50,
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


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


def create_inspection(session, project_id: int) -> Inspection:
    inspection = Inspection(project_id=project_id, inspection_type="MANUAL", status="PENDING")
    session.add(inspection)
    session.commit()
    session.refresh(inspection)
    return inspection


def seed_notification(session, project_id: int, **overrides) -> Notification:
    values = {
        "project_id": project_id,
        "notification_type": "SYSTEM",
        "message": "Seeded notification",
        "source": "SYSTEM",
        "is_read": False,
    }
    values.update(overrides)

    notification = Notification(**values)
    session.add(notification)
    session.commit()
    session.refresh(notification)
    return notification


def notification_payload(project_id: int, **overrides) -> dict:
    payload = {
        "project_id": project_id,
        "notification_type": "SYSTEM",
        "message": "Manual notification",
        "source": "SYSTEM",
    }
    payload.update(overrides)
    return payload


def test_create_notification_success(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        payload = notification_payload(
            project.id,
            notification_type="ALERT",
            severity="HIGH",
            title="Risk alert",
            recipient_id="INS-100",
            recipient_role="officer",
            message="  Project risk level is HIGH  ",
        )

        response = client.post("/notifications", json=payload)

        assert response.status_code == 201
        data = response.json()
        assert data["project_id"] == project.id
        assert data["notification_type"] == "ALERT"
        assert data["severity"] == "HIGH"
        assert data["title"] == "Risk alert"
        assert data["recipient_id"] == "INS-100"
        assert data["recipient_role"] == "officer"
        assert data["message"] == "Project risk level is HIGH"
        assert data["source"] == "SYSTEM"
        assert data["is_read"] is False
        assert data["read_at"] is None
        assert data["alert_id"] is None
        assert data["inspection_id"] is None
        assert data["created_at"] is not None
    finally:
        db.close()


def test_create_notification_without_recipient_is_allowed(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post("/notifications", json=notification_payload(project.id))

        assert response.status_code == 201
        data = response.json()
        assert data["recipient_id"] is None
        assert data["recipient_role"] is None
        assert data["severity"] is None
    finally:
        db.close()


def test_create_notification_for_missing_project_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.post("/notifications", json=notification_payload(99999))
    assert response.status_code == 404


def test_create_notification_with_missing_alert_returns_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        payload = notification_payload(project.id, notification_type="ALERT", alert_id=99999)

        response = client.post("/notifications", json=payload)

        assert response.status_code == 404
        assert response.json()["detail"] == "Alert not found"
    finally:
        db.close()


def test_create_notification_with_alert_from_other_project_returns_400(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        other_project = create_project(db, "Project B")
        alert = create_alert(db, other_project.id)
        payload = notification_payload(project.id, notification_type="ALERT", alert_id=alert.id)

        response = client.post("/notifications", json=payload)

        assert response.status_code == 400
    finally:
        db.close()


def test_create_notification_with_missing_inspection_returns_404(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        payload = notification_payload(
            project.id, notification_type="INSPECTION", inspection_id=99999
        )

        response = client.post("/notifications", json=payload)

        assert response.status_code == 404
        assert response.json()["detail"] == "Inspection not found"
    finally:
        db.close()


def test_create_notification_with_inspection_from_other_project_returns_400(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        other_project = create_project(db, "Project B")
        inspection = create_inspection(db, other_project.id)
        payload = notification_payload(
            project.id, notification_type="INSPECTION", inspection_id=inspection.id
        )

        response = client.post("/notifications", json=payload)

        assert response.status_code == 400
    finally:
        db.close()


def test_create_notification_links_alert_and_inspection(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        alert = create_alert(db, project.id)
        inspection = create_inspection(db, project.id)
        payload = notification_payload(
            project.id,
            notification_type="ALERT",
            alert_id=alert.id,
            inspection_id=inspection.id,
        )

        response = client.post("/notifications", json=payload)

        assert response.status_code == 201
        data = response.json()
        assert data["alert_id"] == alert.id
        assert data["inspection_id"] == inspection.id
    finally:
        db.close()


def test_create_notification_with_invalid_type_is_rejected(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/notifications",
            json=notification_payload(project.id, notification_type="INVALID"),
        )
        assert response.status_code == 422
    finally:
        db.close()


def test_create_notification_with_invalid_severity_is_rejected(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/notifications", json=notification_payload(project.id, severity="INVALID")
        )
        assert response.status_code == 422
    finally:
        db.close()


def test_create_notification_with_blank_message_is_rejected(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        response = client.post(
            "/notifications", json=notification_payload(project.id, message="   ")
        )
        assert response.status_code == 422
    finally:
        db.close()


def test_get_notification_success(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        notification = seed_notification(
            db, project.id, notification_type="ALERT", severity="HIGH"
        )

        response = client.get(f"/notifications/{notification.id}")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == notification.id
        assert data["notification_type"] == "ALERT"
        assert data["severity"] == "HIGH"
        assert data["is_read"] is False
    finally:
        db.close()


def test_get_notification_not_found(client_and_db):
    client, _ = client_and_db
    response = client.get("/notifications/999")
    assert response.status_code == 404


def test_list_notifications_returns_newest_first(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        seed_notification(db, project.id, message="older notification")
        seed_notification(db, project.id, message="newer notification")

        response = client.get("/notifications")

        assert response.status_code == 200
        data = response.json()
        assert [item["message"] for item in data] == [
            "newer notification",
            "older notification",
        ]
    finally:
        db.close()


def test_list_notifications_filters(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        other_project = create_project(db, "Project B")
        seed_notification(
            db,
            project.id,
            notification_type="ALERT",
            recipient_id="INS-1",
            recipient_role="officer",
            message="alert for INS-1",
        )
        seed_notification(
            db,
            project.id,
            notification_type="ASSIGNMENT",
            recipient_id="INS-2",
            recipient_role="supervisor",
            message="assignment for INS-2",
        )
        seed_notification(
            db,
            other_project.id,
            notification_type="ALERT",
            recipient_id="INS-1",
            message="alert for other project",
        )

        by_recipient = client.get("/notifications", params={"recipient_id": "INS-1"})
        assert by_recipient.status_code == 200
        assert {item["message"] for item in by_recipient.json()} == {
            "alert for INS-1",
            "alert for other project",
        }

        by_role = client.get("/notifications", params={"recipient_role": "supervisor"})
        assert by_role.status_code == 200
        assert [item["message"] for item in by_role.json()] == ["assignment for INS-2"]

        by_project = client.get("/notifications", params={"project_id": project.id})
        assert by_project.status_code == 200
        assert len(by_project.json()) == 2

        by_type = client.get("/notifications", params={"notification_type": "ALERT"})
        assert by_type.status_code == 200
        assert {item["notification_type"] for item in by_type.json()} == {"ALERT"}

        limited = client.get("/notifications", params={"limit": 1})
        assert limited.status_code == 200
        assert len(limited.json()) == 1

        invalid_type = client.get("/notifications", params={"notification_type": "INVALID"})
        assert invalid_type.status_code == 422

        invalid_limit = client.get("/notifications", params={"limit": 0})
        assert invalid_limit.status_code == 422
    finally:
        db.close()


def test_list_notifications_is_read_filter(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        seed_notification(db, project.id, message="unread one")
        seed_notification(db, project.id, message="already read", is_read=True)

        unread = client.get("/notifications", params={"is_read": "false"})
        read = client.get("/notifications", params={"is_read": "true"})

        assert unread.status_code == 200
        assert [item["message"] for item in unread.json()] == ["unread one"]
        assert read.status_code == 200
        assert [item["message"] for item in read.json()] == ["already read"]
    finally:
        db.close()


def test_list_notifications_empty_returns_empty_list(client_and_db):
    client, _ = client_and_db
    response = client.get("/notifications")
    assert response.status_code == 200
    assert response.json() == []


def test_list_project_notifications_returns_project_only(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        other_project = create_project(db, "Project B")
        seed_notification(db, project.id, message="project notification")
        seed_notification(db, other_project.id, message="other project notification")

        response = client.get(f"/notifications/project/{project.id}")

        assert response.status_code == 200
        data = response.json()
        assert [item["message"] for item in data] == ["project notification"]
        assert all(item["project_id"] == project.id for item in data)
    finally:
        db.close()


def test_list_project_notifications_missing_project_returns_404(client_and_db):
    client, _ = client_and_db
    response = client.get("/notifications/project/999")
    assert response.status_code == 404


def test_notification_summary_counts_total_and_unread(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        other_project = create_project(db, "Project B")
        seed_notification(db, project.id, recipient_id="INS-1")
        seed_notification(db, project.id, recipient_id="INS-1", is_read=True)
        seed_notification(db, project.id, recipient_id="INS-2")
        seed_notification(db, other_project.id, recipient_id="INS-1")

        overall = client.get("/notifications/summary")
        assert overall.status_code == 200
        assert overall.json() == {"total": 4, "unread": 3}

        by_recipient = client.get("/notifications/summary", params={"recipient_id": "INS-1"})
        assert by_recipient.status_code == 200
        assert by_recipient.json() == {"total": 3, "unread": 2}

        by_project = client.get("/notifications/summary", params={"project_id": project.id})
        assert by_project.status_code == 200
        assert by_project.json() == {"total": 3, "unread": 2}
    finally:
        db.close()


def test_mark_notification_read_sets_read_state_and_timestamp(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        notification = seed_notification(db, project.id)

        response = client.put(f"/notifications/{notification.id}/read")

        assert response.status_code == 200
        data = response.json()
        assert data["is_read"] is True
        assert data["read_at"] is not None

        db.refresh(notification)
        assert notification.is_read is True
        assert notification.read_at is not None
    finally:
        db.close()


def test_mark_notification_read_is_idempotent(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        notification = seed_notification(db, project.id)

        first = client.put(f"/notifications/{notification.id}/read").json()
        second = client.put(f"/notifications/{notification.id}/read").json()

        assert first["read_at"] == second["read_at"]
    finally:
        db.close()


def test_mark_notification_read_not_found(client_and_db):
    client, _ = client_and_db
    response = client.put("/notifications/999/read")
    assert response.status_code == 404


def test_read_all_marks_only_matching_recipient(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        seed_notification(db, project.id, recipient_id="INS-1", message="for INS-1")
        seed_notification(db, project.id, recipient_id="INS-1", message="also for INS-1")
        seed_notification(db, project.id, recipient_id="INS-2", message="for INS-2")

        response = client.put("/notifications/read-all", params={"recipient_id": "INS-1"})

        assert response.status_code == 200
        assert response.json() == {"marked_read": 2}

        unread_for_two = client.get(
            "/notifications", params={"recipient_id": "INS-2", "is_read": "false"}
        )
        assert len(unread_for_two.json()) == 1

        assert client.get("/notifications/summary").json() == {"total": 3, "unread": 1}
    finally:
        db.close()


def test_read_all_supports_project_filter(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        other_project = create_project(db, "Project B")
        seed_notification(db, project.id, message="in project")
        seed_notification(db, other_project.id, message="in other project")

        response = client.put("/notifications/read-all", params={"project_id": project.id})

        assert response.status_code == 200
        assert response.json() == {"marked_read": 1}
        assert client.get("/notifications/summary").json() == {"total": 2, "unread": 1}
    finally:
        db.close()


def test_read_all_without_filters_marks_every_unread(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        build_project = create_project(db, "Project B")
        seed_notification(db, project.id)
        seed_notification(db, build_project.id)

        response = client.put("/notifications/read-all")

        assert response.status_code == 200
        assert response.json() == {"marked_read": 2}
        assert client.get("/notifications/summary").json() == {"total": 2, "unread": 0}
    finally:
        db.close()


def test_read_all_returns_zero_when_nothing_unread(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        seed_notification(db, project.id, is_read=True)

        response = client.put("/notifications/read-all", params={"recipient_id": "INS-1"})

        assert response.status_code == 200
        assert response.json() == {"marked_read": 0}
    finally:
        db.close()


def test_openapi_contains_notification_routes(client_and_db):
    client, _ = client_and_db
    routes = set(client.get("/openapi.json").json()["paths"].keys())

    assert "/notifications" in routes
    assert "/notifications/summary" in routes
    assert "/notifications/read-all" in routes
    assert "/notifications/project/{project_id}" in routes
    assert "/notifications/{notification_id}" in routes
    assert "/notifications/{notification_id}/read" in routes


def test_existing_endpoints_still_work(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        alert = create_alert(db, project.id)
        inspection = create_inspection(db, project.id)

        assert client.get(f"/projects/{project.id}").status_code == 200
        assert client.get(f"/projects/{project.id}/summary").status_code == 200
        assert client.get(f"/alerts/{alert.id}").status_code == 200
        assert client.get(f"/alerts/project/{project.id}").status_code == 200
        assert client.get(f"/inspections/{inspection.id}").status_code == 200
        assert client.get(f"/inspections/project/{project.id}").status_code == 200
        assert client.get(f"/risk/{project.id}").status_code == 200
        assert client.get("/health").status_code == 200

        created = client.post(
            "/inspections",
            json={
                "project_id": project.id,
                "inspection_type": "MANUAL",
                "status": "PENDING",
            },
        )
        assert created.status_code == 201
    finally:
        db.close()
