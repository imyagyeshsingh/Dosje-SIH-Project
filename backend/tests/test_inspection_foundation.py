from datetime import datetime, timezone

import pytest
from pydantic import ValidationError

from app.database import Base
from app.models.ai_detection import AIDetection
from app.models.alert import Alert
from app.models.attendance import Attendance
from app.models.camera import Camera
from app.models.inspection import Inspection
from app.models.inspector import Inspector
from app.models.media import Media
from app.models.notification import Notification
from app.models.project import Project
from app.models.report import Report
from app.models.report_evidence_reference import ReportEvidenceReference
from app.models.video_session import VideoSession
from app.schemas.inspection import InspectionCreate, InspectionResponse


def test_inspection_model_valid_creation():
    inspection = Inspection(
        project_id=1,
        inspection_type="RANDOM",
        status="PENDING",
        scheduled_at=datetime(2026, 9, 20, 9, 30, tzinfo=timezone.utc),
        officer_name="Jane Officer",
        officer_id="OFF-001",
        reason="Routine site check",
        findings="Initial observation",
        result="PASS",
        video_session_id="vs_123",
    )

    assert inspection.project_id == 1
    assert inspection.inspection_type == "RANDOM"
    assert inspection.status == "PENDING"
    assert inspection.officer_name == "Jane Officer"
    assert inspection.officer_id == "OFF-001"
    assert inspection.video_session_id == "vs_123"


def test_valid_inspection_types_are_accepted():
    for inspection_type in ["RANDOM", "ALERT_TRIGGERED", "SCHEDULED", "MANUAL"]:
        payload = InspectionCreate(
            project_id=1,
            inspection_type=inspection_type,
            status="PENDING",
        )
        assert payload.inspection_type == inspection_type


def test_invalid_inspection_type_is_rejected():
    with pytest.raises(ValidationError):
        InspectionCreate(
            project_id=1,
            inspection_type="INVALID",
            status="PENDING",
        )


def test_valid_statuses_are_accepted():
    for status in ["PENDING", "SCHEDULED", "IN_PROGRESS", "COMPLETED", "CANCELLED"]:
        payload = InspectionCreate(
            project_id=1,
            inspection_type="MANUAL",
            status=status,
        )
        assert payload.status == status


def test_invalid_status_is_rejected():
    with pytest.raises(ValidationError):
        InspectionCreate(
            project_id=1,
            inspection_type="MANUAL",
            status="INVALID",
        )


def test_project_id_must_be_positive():
    with pytest.raises(ValidationError):
        InspectionCreate(project_id=0, inspection_type="RANDOM", status="PENDING")


def test_optional_fields_are_supported():
    payload = InspectionCreate(
        project_id=2,
        inspection_type="SCHEDULED",
        status="SCHEDULED",
        scheduled_at=datetime(2026, 9, 21, 12, 0, tzinfo=timezone.utc),
        officer_name=None,
        officer_id=None,
        reason=None,
        findings=None,
        result=None,
        video_session_id=None,
    )

    assert payload.officer_name is None
    assert payload.officer_id is None
    assert payload.reason is None
    assert payload.findings is None
    assert payload.result is None
    assert payload.video_session_id is None


def test_inspection_response_supports_sqlalchemy_objects():
    inspection = Inspection(
        id=1,
        project_id=7,
        inspection_type="ALERT_TRIGGERED",
        status="IN_PROGRESS",
        officer_name="Sam",
        reason="Alert triggered",
        created_at=datetime(2026, 9, 20, 8, 0, tzinfo=timezone.utc),
        updated_at=datetime(2026, 9, 20, 8, 15, tzinfo=timezone.utc),
    )

    response = InspectionResponse.model_validate(inspection)
    assert response.project_id == 7
    assert response.inspection_type == "ALERT_TRIGGERED"
    assert response.status == "IN_PROGRESS"
    assert response.officer_name == "Sam"


def test_insppections_table_is_registered_in_metadata():
    assert "inspections" in Base.metadata.tables
