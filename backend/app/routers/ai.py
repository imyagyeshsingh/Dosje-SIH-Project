import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.ai_detection import AIDetection
from app.models.camera import Camera
from app.models.project import Project
from app.schemas.ai_detection import (
    AIDetectionCreate,
    AIDetectionResponse,
    AIDetectionSummaryResponse,
)
from app.services.alert_service import generate_project_alerts
from app.services.audit_log_service import create_audit_log

logger = logging.getLogger(__name__)


router = APIRouter(prefix="/ai", tags=["AI Detection"])


def get_project_or_404(project_id: int, db: Session) -> Project:
    project = db.get(Project, project_id)
    if project is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    return project


@router.post(
    "/detection", response_model=AIDetectionResponse, status_code=status.HTTP_201_CREATED
)
def create_ai_detection(
    detection_data: AIDetectionCreate, db: Session = Depends(get_db)
) -> AIDetection:
    get_project_or_404(detection_data.project_id, db)

    camera = db.get(Camera, detection_data.camera_id)
    if camera is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Camera not found")

    if camera.project_id != detection_data.project_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Camera does not belong to the supplied project",
        )

    detection = AIDetection(**detection_data.model_dump())
    try:
        db.add(detection)
        db.commit()
        db.refresh(detection)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save AI detection",
        )

    create_audit_log(
        db=db,
        project_id=detection.project_id,
        entity_type="AI_DETECTION",
        entity_id=detection.id,
        action="CREATED",
    )

    try:
        generate_project_alerts(detection.project_id, db)
    except Exception:
        logger.exception(
            "Failed to evaluate project alerts after AI detection %s for project %s",
            detection.id,
            detection.project_id,
        )

    return detection


@router.get("/detection/{project_id}", response_model=list[AIDetectionResponse])
def list_project_detections(
    project_id: int,
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[AIDetection]:
    get_project_or_404(project_id, db)

    statement = (
        select(AIDetection)
        .where(AIDetection.project_id == project_id)
        .order_by(AIDetection.timestamp.desc(), AIDetection.id.desc())
        .limit(limit)
        .offset(offset)
    )
    return list(db.scalars(statement).all())


@router.get("/detection/{project_id}/summary", response_model=AIDetectionSummaryResponse)
def get_project_detection_summary(
    project_id: int, db: Session = Depends(get_db)
) -> AIDetectionSummaryResponse:
    get_project_or_404(project_id, db)

    detection_count = (
        db.scalar(
            select(func.count())
            .select_from(AIDetection)
            .where(AIDetection.project_id == project_id)
        )
        or 0
    )

    latest = db.scalars(
        select(AIDetection)
        .where(AIDetection.project_id == project_id)
        .order_by(AIDetection.timestamp.desc(), AIDetection.id.desc())
        .limit(1)
    ).first()

    if latest is None:
        return AIDetectionSummaryResponse(project_id=project_id, detection_count=detection_count)

    return AIDetectionSummaryResponse(
        project_id=project_id,
        latest_people_detected=latest.people_detected,
        latest_activity=latest.activity,
        latest_confidence=latest.confidence,
        latest_timestamp=latest.timestamp,
        detection_count=detection_count,
    )
