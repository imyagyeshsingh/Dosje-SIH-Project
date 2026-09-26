from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.ai_detection import AIDetection
from app.models.attendance import Attendance
from app.models.project import Project
from app.schemas.attendance import (
    AttendanceCreate,
    AttendanceResponse,
    AttendanceSummaryResponse,
    AttendanceUpdate,
)


router = APIRouter(prefix="/attendance", tags=["Attendance"])


def get_project_or_404(project_id: int, db: Session) -> Project:
    project = db.get(Project, project_id)
    if project is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    return project


def get_attendance_or_404(project_id: int, db: Session) -> Attendance:
    attendance = db.scalars(select(Attendance).where(Attendance.project_id == project_id)).first()
    if attendance is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance configuration not found for this project",
        )
    return attendance


def get_latest_detection(project_id: int, db: Session) -> AIDetection | None:
    return db.scalars(
        select(AIDetection)
        .where(AIDetection.project_id == project_id)
        .order_by(AIDetection.timestamp.desc(), AIDetection.id.desc())
        .limit(1)
    ).first()


@router.post("", response_model=AttendanceResponse, status_code=status.HTTP_201_CREATED)
def create_attendance_config(
    attendance_data: AttendanceCreate, db: Session = Depends(get_db)
) -> Attendance:
    get_project_or_404(attendance_data.project_id, db)

    existing = db.scalars(
        select(Attendance).where(Attendance.project_id == attendance_data.project_id)
    ).first()
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Attendance configuration already exists for this project",
        )

    attendance = Attendance(**attendance_data.model_dump())
    db.add(attendance)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Attendance configuration already exists for this project",
        )
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create attendance configuration",
        )

    db.refresh(attendance)
    return attendance


@router.get("/summary/{project_id}", response_model=AttendanceSummaryResponse)
def get_attendance_summary(
    project_id: int, db: Session = Depends(get_db)
) -> AttendanceSummaryResponse:
    get_project_or_404(project_id, db)

    attendance = db.scalars(select(Attendance).where(Attendance.project_id == project_id)).first()
    latest_detection = get_latest_detection(project_id, db)

    expected_workers = attendance.expected_workers if attendance is not None else None
    detected_workers = latest_detection.people_detected if latest_detection is not None else None
    detection_timestamp = latest_detection.timestamp if latest_detection is not None else None

    attendance_percentage: float | None = None
    if expected_workers is not None and expected_workers > 0 and detected_workers is not None:
        attendance_percentage = round(detected_workers / expected_workers * 100, 2)

    return AttendanceSummaryResponse(
        project_id=project_id,
        expected_workers=expected_workers,
        detected_workers=detected_workers,
        attendance_percentage=attendance_percentage,
        detection_timestamp=detection_timestamp,
    )


@router.get("/{project_id}", response_model=AttendanceResponse)
def get_attendance_config(project_id: int, db: Session = Depends(get_db)) -> Attendance:
    get_project_or_404(project_id, db)
    return get_attendance_or_404(project_id, db)


@router.put("/{project_id}", response_model=AttendanceResponse)
def update_attendance_config(
    project_id: int, attendance_data: AttendanceUpdate, db: Session = Depends(get_db)
) -> Attendance:
    get_project_or_404(project_id, db)
    attendance = get_attendance_or_404(project_id, db)

    attendance.expected_workers = attendance_data.expected_workers
    try:
        db.commit()
        db.refresh(attendance)
        return attendance
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update attendance configuration",
        )
