from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.inspection import Inspection
from app.models.project import Project
from app.models.report import Report
from app.models.report_evidence_reference import ReportEvidenceReference
from app.schemas.report import ReportCreate, ReportResponse, ReportUpdate
from app.schemas.report_aggregation import ReportAggregationResponse
from app.schemas.report_evidence_reference import (
    ReportEvidenceReferenceCreate,
    ReportEvidenceReferenceResponse,
)
from app.services.report_aggregation import aggregate_report_data


router = APIRouter(prefix="/reports", tags=["Reports"])


def get_project_or_404(project_id: int, db: Session) -> Project:
    project = db.get(Project, project_id)
    if project is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    return project


def get_inspection_or_404(inspection_id: int, db: Session) -> Inspection:
    inspection = db.get(Inspection, inspection_id)
    if inspection is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inspection not found")
    return inspection


def get_report_or_404(report_id: int, db: Session) -> Report:
    report = db.get(Report, report_id)
    if report is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Report not found")
    return report


def validate_report_link(project_id: int, inspection_id: int, db: Session) -> None:
    get_project_or_404(project_id, db)
    inspection = get_inspection_or_404(inspection_id, db)
    if inspection.project_id != project_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inspection does not belong to the specified project",
        )


@router.post("", response_model=ReportResponse, status_code=status.HTTP_201_CREATED)
def create_report(report_data: ReportCreate, db: Session = Depends(get_db)) -> Report:
    validate_report_link(report_data.project_id, report_data.inspection_id, db)

    report = Report(**report_data.model_dump())
    db.add(report)
    try:
        db.commit()
        db.refresh(report)
        return report
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create report",
        )


@router.get("/{report_id}", response_model=ReportResponse)
def get_report(report_id: int, db: Session = Depends(get_db)) -> Report:
    return get_report_or_404(report_id, db)


@router.get("/project/{project_id}", response_model=list[ReportResponse])
def list_project_reports(
    project_id: int,
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[Report]:
    get_project_or_404(project_id, db)
    statement = (
        select(Report)
        .where(Report.project_id == project_id)
        .order_by(Report.created_at.desc(), Report.id.desc())
        .limit(limit)
        .offset(offset)
    )
    return list(db.scalars(statement).all())


@router.put("/{report_id}", response_model=ReportResponse)
def update_report(
    report_id: int,
    report_data: ReportUpdate,
    db: Session = Depends(get_db),
) -> Report:
    report = get_report_or_404(report_id, db)
    updates = report_data.model_dump(exclude_unset=True)

    if "project_id" in updates and updates["project_id"] is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="project_id cannot be null",
        )
    if "inspection_id" in updates and updates["inspection_id"] is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="inspection_id cannot be null",
        )

    if "project_id" in updates or "inspection_id" in updates:
        target_project_id = updates.get("project_id", report.project_id)
        target_inspection_id = updates.get("inspection_id", report.inspection_id)
        if target_project_id is None or target_inspection_id is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="project_id and inspection_id cannot be null",
            )
        validate_report_link(target_project_id, target_inspection_id, db)

    for field, value in updates.items():
        setattr(report, field, value)

    try:
        db.commit()
        db.refresh(report)
        return report
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update report",
        )


@router.post(
    "/{report_id}/evidence",
    response_model=ReportEvidenceReferenceResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_report_evidence(
    report_id: int,
    evidence_data: ReportEvidenceReferenceCreate,
    db: Session = Depends(get_db),
) -> ReportEvidenceReference:
    report = get_report_or_404(report_id, db)

    existing = db.scalar(
        select(ReportEvidenceReference)
        .where(ReportEvidenceReference.report_id == report.id)
        .where(ReportEvidenceReference.external_evidence_id == evidence_data.external_evidence_id)
        .limit(1)
    )
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Evidence reference already exists for this report",
        )

    reference = ReportEvidenceReference(
        report_id=report.id,
        external_evidence_id=evidence_data.external_evidence_id,
        evidence_type=evidence_data.evidence_type.value,
        source=evidence_data.source,
    )
    db.add(reference)
    try:
        db.commit()
        db.refresh(reference)
        return reference
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save evidence reference",
        )


@router.get("/{report_id}/evidence", response_model=list[ReportEvidenceReferenceResponse])
def list_report_evidence(
    report_id: int,
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[ReportEvidenceReference]:
    get_report_or_404(report_id, db)
    statement = (
        select(ReportEvidenceReference)
        .where(ReportEvidenceReference.report_id == report_id)
        .order_by(ReportEvidenceReference.created_at.desc(), ReportEvidenceReference.id.desc())
        .limit(limit)
        .offset(offset)
    )
    return list(db.scalars(statement).all())


@router.delete("/{report_id}/evidence/{reference_id}")
def delete_report_evidence(
    report_id: int,
    reference_id: int,
    db: Session = Depends(get_db),
) -> dict[str, str]:
    get_report_or_404(report_id, db)
    reference = db.get(ReportEvidenceReference, reference_id)
    if reference is None or reference.report_id != report_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Evidence reference not found for this report",
        )

    try:
        db.delete(reference)
        db.commit()
        return {"message": "Evidence reference deleted successfully"}
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete evidence reference",
        )


@router.get("/{report_id}/aggregation", response_model=ReportAggregationResponse)
def get_report_aggregation(report_id: int, db: Session = Depends(get_db)) -> dict:
    report = get_report_or_404(report_id, db)
    return aggregate_report_data(report, db)
