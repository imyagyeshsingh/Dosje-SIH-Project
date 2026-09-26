from datetime import datetime, timezone
from decimal import Decimal

import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine, inspect
from sqlalchemy.orm import Session, sessionmaker

from app.database import Base

# Import every model module so Base.metadata is complete before create_all(),
# mirroring the model imports in app/main.py.
from app.models.ai_detection import AIDetection  # noqa: F401
from app.models.alert import Alert
from app.models.attendance import Attendance  # noqa: F401
from app.models.camera import Camera  # noqa: F401
from app.models.inspection import Inspection
from app.models.inspector import Inspector  # noqa: F401
from app.models.media import Media  # noqa: F401
from app.models.notification import Notification
from app.models.project import Project
from app.models.report import Report  # noqa: F401
from app.models.report_evidence_reference import ReportEvidenceReference  # noqa: F401
from app.models.video_session import VideoSession  # noqa: F401
from app.schemas.notification import (
    NotificationCreate,
    NotificationResponse,
    NotificationSeverity,
    NotificationSummaryResponse,
    NotificationType,
)


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(bind=engine)
    session = SessionLocal()
    yield session
    session.close()
    Base.metadata.drop_all(bind=engine)


def create_project(session: Session) -> Project:
    project = Project(
        project_name="Notification Project",
        project_code="NOTIF-001",
        status="ACTIVE",
        progress=Decimal("0"),
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def test_notification_model_can_be_created(db_session: Session):
    project = create_project(db_session)
    notification = Notification(
        project_id=project.id,
        recipient_id="INS-100",
        recipient_role="officer",
        notification_type="SYSTEM",
        severity="LOW",
        title="Maintenance window",
        message="Scheduled maintenance tonight",
        source="SYSTEM",
    )
    db_session.add(notification)
    db_session.commit()
    db_session.refresh(notification)

    assert notification.id is not None
    assert notification.project_id == project.id
    assert notification.recipient_id == "INS-100"
    assert notification.recipient_role == "officer"
    assert notification.notification_type == "SYSTEM"
    assert notification.severity == "LOW"
    assert notification.created_at is not None
    assert notification.updated_at is not None


def test_read_state_defaults_to_unread(db_session: Session):
    project = create_project(db_session)
    notification = Notification(
        project_id=project.id,
        notification_type="ALERT",
        message="Alert raised",
        source="ALERT_ENGINE",
    )
    db_session.add(notification)
    db_session.commit()
    db_session.refresh(notification)

    assert notification.is_read is False
    assert notification.read_at is None


def test_read_state_can_be_marked_read_with_timestamp(db_session: Session):
    project = create_project(db_session)
    notification = Notification(
        project_id=project.id,
        notification_type="ALERT",
        message="Alert raised",
        source="ALERT_ENGINE",
    )
    db_session.add(notification)
    db_session.commit()
    db_session.refresh(notification)

    read_at = datetime(2026, 9, 22, 10, 0, tzinfo=timezone.utc)
    notification.is_read = True
    notification.read_at = read_at
    db_session.commit()
    db_session.refresh(notification)

    assert notification.is_read is True
    assert notification.read_at.replace(tzinfo=timezone.utc) == read_at


def test_notification_can_reference_alert_and_inspection(db_session: Session):
    project = create_project(db_session)
    alert = Alert(
        project_id=project.id,
        alert_type="RISK",
        severity="HIGH",
        message="Risk threshold exceeded",
        status="OPEN",
        source="RISK_ENGINE",
    )
    inspection = Inspection(project_id=project.id, inspection_type="MANUAL", status="PENDING")
    db_session.add_all([alert, inspection])
    db_session.commit()
    db_session.refresh(alert)
    db_session.refresh(inspection)

    notification = Notification(
        project_id=project.id,
        notification_type="INSPECTION",
        message="Inspection created",
        source="INSPECTION_ENGINE",
        alert_id=alert.id,
        inspection_id=inspection.id,
    )
    db_session.add(notification)
    db_session.commit()
    db_session.refresh(notification)

    assert notification.alert_id == alert.id
    assert notification.inspection_id == inspection.id


def test_valid_notification_types_are_accepted():
    for notification_type in [
        "ALERT",
        "INSPECTION",
        "ASSIGNMENT",
        "REPORT",
        "VIDEO_SESSION",
        "SYSTEM",
    ]:
        payload = NotificationCreate(
            project_id=1,
            notification_type=notification_type,
            message="Something happened",
            source="SYSTEM",
        )
        assert payload.notification_type == notification_type


def test_invalid_notification_type_is_rejected():
    with pytest.raises(ValidationError):
        NotificationCreate(
            project_id=1,
            notification_type="INVALID",
            message="Something happened",
            source="SYSTEM",
        )


def test_valid_severities_are_accepted():
    for severity in ["LOW", "MEDIUM", "HIGH", "CRITICAL"]:
        payload = NotificationCreate(
            project_id=1,
            notification_type="ALERT",
            message="Alert raised",
            source="ALERT_ENGINE",
            severity=severity,
        )
        assert payload.severity == NotificationSeverity(severity)


def test_invalid_severity_is_rejected():
    with pytest.raises(ValidationError):
        NotificationCreate(
            project_id=1,
            notification_type="ALERT",
            message="Alert raised",
            source="ALERT_ENGINE",
            severity="INVALID",
        )


def test_severity_is_optional():
    payload = NotificationCreate(
        project_id=1,
        notification_type="SYSTEM",
        message="No severity required",
        source="SYSTEM",
    )
    assert payload.severity is None


def test_blank_message_is_rejected():
    with pytest.raises(ValidationError):
        NotificationCreate(
            project_id=1,
            notification_type="SYSTEM",
            message="   ",
            source="SYSTEM",
        )


def test_blank_source_is_rejected():
    with pytest.raises(ValidationError):
        NotificationCreate(
            project_id=1,
            notification_type="SYSTEM",
            message="Valid message",
            source="   ",
        )


def test_message_length_limit_is_enforced():
    with pytest.raises(ValidationError):
        NotificationCreate(
            project_id=1,
            notification_type="SYSTEM",
            message="x" * 501,
            source="SYSTEM",
        )


def test_blank_optional_text_is_normalized_to_none():
    payload = NotificationCreate(
        project_id=1,
        notification_type="SYSTEM",
        message="Valid message",
        source="SYSTEM",
        title="   ",
        recipient_id="   ",
        recipient_role="",
    )

    assert payload.title is None
    assert payload.recipient_id is None
    assert payload.recipient_role is None


def test_recipient_fields_are_optional():
    payload = NotificationCreate(
        project_id=1,
        notification_type="SYSTEM",
        message="Broadcast notification",
        source="SYSTEM",
    )

    assert payload.recipient_id is None
    assert payload.recipient_role is None
    assert payload.alert_id is None
    assert payload.inspection_id is None


def test_notification_check_constraints_are_declared():
    constraint_names = {
        constraint.name for constraint in Notification.__table__.constraints
    }

    assert "ck_notifications_notification_type" in constraint_names
    assert "ck_notifications_severity" in constraint_names


def test_notification_response_supports_sqlalchemy_objects():
    notification = Notification(
        id=5,
        project_id=3,
        recipient_id="INS-9",
        recipient_role="officer",
        notification_type="ASSIGNMENT",
        severity="MEDIUM",
        title="Inspection assignment",
        message="Inspection assigned to Inspector Jane",
        source="ASSIGNMENT_ENGINE",
        inspection_id=12,
        is_read=False,
        read_at=None,
        created_at=datetime(2026, 9, 22, 9, 0, tzinfo=timezone.utc),
        updated_at=datetime(2026, 9, 22, 9, 0, tzinfo=timezone.utc),
    )

    response = NotificationResponse.model_validate(notification)

    assert response.notification_type == NotificationType.ASSIGNMENT
    assert response.severity == NotificationSeverity.MEDIUM
    assert response.recipient_id == "INS-9"
    assert response.is_read is False
    assert response.inspection_id == 12


def test_notification_summary_response_defaults():
    summary = NotificationSummaryResponse()

    assert summary.total == 0
    assert summary.unread == 0
