from decimal import Decimal

import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine, inspect
from sqlalchemy.orm import Session, sessionmaker

from app.database import Base
from app.models.alert import Alert
from app.models.project import Project
from app.routers.risk import calculate_project_risk
from app.schemas.alert import AlertCreate, AlertResponse, AlertSeverity, AlertStatus, AlertType


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
        project_name="Test Project",
        project_code="TP-001",
        status="ACTIVE",
        progress=Decimal("0"),
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def test_alert_model_can_be_created(db_session: Session):
    project = create_project(db_session)
    alert = Alert(
        project_id=project.id,
        alert_type="RISK",
        severity="HIGH",
        message="Risk threshold exceeded",
        status="OPEN",
        source="SYSTEM",
    )
    db_session.add(alert)
    db_session.commit()
    db_session.refresh(alert)

    assert alert.id is not None
    assert alert.project_id == project.id
    assert alert.alert_type == "RISK"
    assert alert.severity == "HIGH"
    assert alert.status == "OPEN"
    assert alert.created_at is not None
    assert alert.updated_at is not None


def test_alert_create_valid_schema():
    payload = AlertCreate(
        project_id=1,
        alert_type=AlertType.RISK,
        severity=AlertSeverity.HIGH,
        message="High risk detected",
        confidence=0.92,
        status=AlertStatus.OPEN,
        source="AI",
        detection_id=15,
    )

    assert payload.project_id == 1
    assert payload.alert_type == AlertType.RISK
    assert payload.severity == AlertSeverity.HIGH
    assert payload.status == AlertStatus.OPEN
    assert payload.confidence == 0.92


def test_empty_message_fails():
    with pytest.raises(ValidationError):
        AlertCreate(
            project_id=1,
            alert_type=AlertType.RISK,
            severity=AlertSeverity.MEDIUM,
            message="   ",
        )


def test_invalid_severity_fails():
    with pytest.raises(ValidationError):
        AlertCreate(
            project_id=1,
            alert_type=AlertType.CAMERA,
            severity="INVALID",
            message="Camera offline",
        )


def test_invalid_status_fails():
    with pytest.raises(ValidationError):
        AlertCreate(
            project_id=1,
            alert_type=AlertType.ATTENDANCE,
            severity=AlertSeverity.LOW,
            message="Attendance low",
            status="INVALID",
        )


def test_invalid_confidence_fails():
    with pytest.raises(ValidationError):
        AlertCreate(
            project_id=1,
            alert_type=AlertType.AI_ACTIVITY,
            severity=AlertSeverity.HIGH,
            message="Suspicious movement",
            confidence=1.5,
        )


def test_optional_detection_id_works():
    payload = AlertCreate(
        project_id=2,
        alert_type=AlertType.CAMERA,
        severity=AlertSeverity.CRITICAL,
        message="Camera offline",
        detection_id=None,
    )

    assert payload.detection_id is None
    assert isinstance(payload, AlertCreate)


def test_alert_can_reference_existing_project(db_session: Session):
    project = create_project(db_session)
    payload = AlertCreate(
        project_id=project.id,
        alert_type=AlertType.ATTENDANCE,
        severity=AlertSeverity.MEDIUM,
        message="Low attendance",
    )

    assert payload.project_id == project.id
    assert payload.alert_type == AlertType.ATTENDANCE


def test_alert_table_is_created(db_session: Session):
    inspector = inspect(db_session.bind)
    assert "alerts" in inspector.get_table_names()


def test_existing_tables_still_exist(db_session: Session):
    inspector = inspect(db_session.bind)
    tables = inspector.get_table_names()
    assert "projects" in tables
    assert "cameras" in tables
    assert "ai_detections" in tables
    assert "attendance" in tables


def test_risk_behavior_unchanged(db_session: Session):
    project = Project(
        project_name="Risk Check",
        project_code="RC-001",
        status="ACTIVE",
        progress=Decimal("0"),
    )
    response = calculate_project_risk(project, db_session)
    assert response.score == 100
    assert response.level.value == "CRITICAL"


def test_alert_response_model_from_attributes():
    alert = Alert(
        id=7,
        project_id=1,
        alert_type="AI_ACTIVITY",
        severity="LOW",
        message="Mild irregular activity",
        confidence=0.4,
        status="OPEN",
        source="AI",
        created_at=__import__("datetime").datetime.now(),
        updated_at=__import__("datetime").datetime.now(),
    )

    response = AlertResponse.model_validate(alert)
    assert response.alert_type == AlertType.AI_ACTIVITY
    assert response.severity == AlertSeverity.LOW
    assert response.status == AlertStatus.OPEN
    assert response.confidence == 0.4
