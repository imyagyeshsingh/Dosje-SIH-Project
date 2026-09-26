from datetime import datetime, timezone

import pytest
from pydantic import ValidationError

from app.database import Base
from app.models.report import Report
from app.schemas.report import ReportCreate, ReportResponse, ReportStatus, ReportType


def test_report_model_can_be_imported():
    assert Report.__tablename__ == "reports"


def test_report_table_metadata_is_registered():
    assert "reports" in Base.metadata.tables


def test_report_required_fields_exist():
    report = Report(
        project_id=1,
        inspection_id=2,
        report_type="INSPECTION",
        status="DRAFT",
        title="Inspection report",
        summary="Summary text",
        findings="Findings text",
        recommendations="Recommendations text",
        generated_at=datetime(2026, 9, 20, 8, 0, tzinfo=timezone.utc),
        created_at=datetime(2026, 9, 20, 8, 5, tzinfo=timezone.utc),
        updated_at=datetime(2026, 9, 20, 8, 10, tzinfo=timezone.utc),
    )

    assert report.project_id == 1
    assert report.inspection_id == 2
    assert report.report_type == "INSPECTION"
    assert report.status == "DRAFT"
    assert report.title == "Inspection report"
    assert report.summary == "Summary text"
    assert report.findings == "Findings text"
    assert report.recommendations == "Recommendations text"
    assert report.generated_at == datetime(2026, 9, 20, 8, 0, tzinfo=timezone.utc)


def test_report_foreign_keys_point_to_projects_and_inspections():
    report = Report(
        project_id=11,
        inspection_id=22,
        report_type="MONITORING",
        status="FINAL",
        title="Monitoring report",
        summary="Monitor summary",
        findings="Monitor findings",
        recommendations="Monitor recommendations",
    )

    assert report.project_id == 11
    assert report.inspection_id == 22


def test_valid_report_type_values_are_accepted():
    for report_type in ["INSPECTION", "MONITORING", "INCIDENT"]:
        payload = ReportCreate(
            project_id=1,
            inspection_id=2,
            report_type=report_type,
            status="DRAFT",
            title="Valid title",
            summary="Summary text",
            findings="Findings text",
            recommendations="Recommendations text",
        )
        assert payload.report_type == report_type


def test_valid_status_values_are_accepted():
    for status in ["DRAFT", "FINAL"]:
        payload = ReportCreate(
            project_id=1,
            inspection_id=2,
            report_type="INSPECTION",
            status=status,
            title="Status title",
            summary="Summary text",
            findings="Findings text",
            recommendations="Recommendations text",
        )
        assert payload.status == status


def test_invalid_enum_values_are_rejected():
    with pytest.raises(ValidationError):
        ReportCreate(
            project_id=1,
            inspection_id=2,
            report_type="INVALID",
            status="DRAFT",
            title="Bad title",
            summary="Summary text",
            findings="Findings text",
            recommendations="Recommendations text",
        )

    with pytest.raises(ValidationError):
        ReportCreate(
            project_id=1,
            inspection_id=2,
            report_type="INSPECTION",
            status="INVALID",
            title="Bad title",
            summary="Summary text",
            findings="Findings text",
            recommendations="Recommendations text",
        )


def test_report_response_supports_sqlalchemy_objects():
    report = Report(
        id=7,
        project_id=1,
        inspection_id=2,
        report_type="INCIDENT",
        status="FINAL",
        title="Incident report",
        summary="Incidents summary",
        findings="Some findings",
        recommendations="Some recommendations",
        generated_at=datetime(2026, 9, 20, 12, 0, tzinfo=timezone.utc),
        created_at=datetime(2026, 9, 20, 12, 5, tzinfo=timezone.utc),
        updated_at=datetime(2026, 9, 20, 12, 10, tzinfo=timezone.utc),
    )

    response = ReportResponse.model_validate(report)
    assert response.project_id == 1
    assert response.inspection_id == 2
    assert response.report_type == ReportType.INCIDENT
    assert response.status == ReportStatus.FINAL
    assert response.title == "Incident report"


def test_project_and_inspection_ids_must_be_positive():
    with pytest.raises(ValidationError):
        ReportCreate(
            project_id=0,
            inspection_id=1,
            report_type="INSPECTION",
            status="DRAFT",
            title="Invalid project id",
            summary="Summary text",
            findings="Findings text",
            recommendations="Recommendations text",
        )

    with pytest.raises(ValidationError):
        ReportCreate(
            project_id=1,
            inspection_id=0,
            report_type="INSPECTION",
            status="DRAFT",
            title="Invalid inspection id",
            summary="Summary text",
            findings="Findings text",
            recommendations="Recommendations text",
        )
