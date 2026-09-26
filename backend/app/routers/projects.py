from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.ai_detection import AIDetection
from app.models.alert import Alert
from app.models.attendance import Attendance
from app.models.camera import Camera
from app.models.inspection import Inspection
from app.models.media import Media
from app.models.notification import Notification
from app.models.project import Project
from app.models.report import Report
from app.models.video_session import VideoSession
from app.routers.risk import calculate_project_risk
from app.schemas.project import (
    AlertsSummary,
    ProjectCreate,
    ProjectResponse,
    ProjectSummaryResponse,
    ProjectUpdate,
)


router = APIRouter(prefix="/projects", tags=["Projects"])


def get_project_or_404(project_id: int, db: Session) -> Project:
    project = db.get(Project, project_id)
    if project is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    return project


@router.post("", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
def create_project(project_data: ProjectCreate, db: Session = Depends(get_db)) -> Project:
    project = Project(**project_data.model_dump())
    db.add(project)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A project with this project_code already exists",
        )
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create project",
        )

    db.refresh(project)
    return project


@router.get("", response_model=list[ProjectResponse])
def list_projects(
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[Project]:
    statement = select(Project).order_by(Project.created_at.desc()).limit(limit).offset(offset)
    return list(db.scalars(statement).all())


@router.get("/{project_id}/summary", response_model=ProjectSummaryResponse)
def get_project_summary(
    project_id: int, db: Session = Depends(get_db)
) -> ProjectSummaryResponse:
    project = get_project_or_404(project_id, db)
    risk = calculate_project_risk(project, db)

    total_alerts = db.scalar(
        select(func.count()).select_from(Alert).where(Alert.project_id == project_id)
    ) or 0
    active_alerts = db.scalar(
        select(func.count())
        .select_from(Alert)
        .where(Alert.project_id == project_id)
        .where(Alert.status.in_(["OPEN", "ACKNOWLEDGED"]))
    ) or 0

    return ProjectSummaryResponse(
        project=project,
        risk=risk.model_dump(mode="json"),
        alerts=AlertsSummary(total=int(total_alerts), active=int(active_alerts)),
    )


@router.get("/{project_id}", response_model=ProjectResponse)
def get_project(project_id: int, db: Session = Depends(get_db)) -> Project:
    return get_project_or_404(project_id, db)


@router.put("/{project_id}", response_model=ProjectResponse)
def update_project(
    project_id: int, project_data: ProjectUpdate, db: Session = Depends(get_db)
) -> Project:
    project = get_project_or_404(project_id, db)
    updates = project_data.model_dump(exclude_unset=True)

    for field, value in updates.items():
        if field in {"project_name", "project_code", "status", "progress"} and value is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"{field} cannot be null",
            )
        setattr(project, field, value)

    if (
        project.start_date is not None
        and project.expected_end_date is not None
        and project.expected_end_date < project.start_date
    ):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="expected_end_date must be on or after start_date",
        )

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A project with this project_code already exists",
        )
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update project",
        )

    db.refresh(project)
    return project


def check_project_dependencies(project_id: int, db: Session) -> bool:
    dependency_models = (
        Camera,
        Media,
        Inspection,
        Alert,
        Attendance,
        AIDetection,
        Notification,
        Report,
        VideoSession,
    )
    for model in dependency_models:
        if db.scalar(select(model.id).where(model.project_id == project_id).limit(1)) is not None:
            return True
    return False


@router.delete("/{project_id}")
def delete_project(project_id: int, db: Session = Depends(get_db)) -> dict[str, str]:
    project = get_project_or_404(project_id, db)

    if check_project_dependencies(project_id, db):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Project cannot be deleted while dependent records exist",
        )

    try:
        db.delete(project)
        db.commit()
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete project",
        )

    return {"message": "Project deleted successfully"}
