from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.ai_detection import AIDetection
from app.models.alert import Alert
from app.models.project import Project
from app.schemas.alert import AlertCreate, AlertResponse, AlertUpdate
from app.services.alert_service import generate_project_alerts


router = APIRouter(prefix="/alerts", tags=["Alerts"])


def get_project_or_404(project_id: int, db: Session) -> Project:
    project = db.get(Project, project_id)
    if project is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    return project


def get_alert_or_404(alert_id: int, db: Session) -> Alert:
    alert = db.get(Alert, alert_id)
    if alert is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Alert not found")
    return alert


@router.post("", response_model=AlertResponse, status_code=status.HTTP_201_CREATED)
def create_alert(alert_data: AlertCreate, db: Session = Depends(get_db)) -> Alert:
    get_project_or_404(alert_data.project_id, db)

    if alert_data.detection_id is not None:
        detection = db.get(AIDetection, alert_data.detection_id)
        if detection is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Detection not found")
        if detection.project_id != alert_data.project_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Detection does not belong to the supplied project",
            )

    alert = Alert(**alert_data.model_dump())
    try:
        db.add(alert)
        db.commit()
        db.refresh(alert)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save alert",
        )
    return alert


@router.get("/{alert_id}", response_model=AlertResponse)
def get_alert(alert_id: int, db: Session = Depends(get_db)) -> Alert:
    return get_alert_or_404(alert_id, db)


@router.get("/project/{project_id}", response_model=list[AlertResponse])
def list_project_alerts(
    project_id: int,
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[Alert]:
    get_project_or_404(project_id, db)

    statement = (
        select(Alert)
        .where(Alert.project_id == project_id)
        .order_by(Alert.created_at.desc(), Alert.id.desc())
        .limit(limit)
        .offset(offset)
    )
    return list(db.scalars(statement).all())


@router.post("/generate/{project_id}", response_model=list[AlertResponse], status_code=200)
def generate_alerts_for_project(project_id: int, db: Session = Depends(get_db)) -> list[Alert]:
    try:
        return generate_project_alerts(project_id, db)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate alerts for project",
        )


@router.put("/{alert_id}/status", response_model=AlertResponse)
def update_alert_status(
    alert_id: int,
    status_data: AlertUpdate,
    db: Session = Depends(get_db),
) -> Alert:
    alert = get_alert_or_404(alert_id, db)

    if status_data.status is not None:
        alert.status = status_data.status

    try:
        db.commit()
        db.refresh(alert)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update alert status",
        )
    return alert
