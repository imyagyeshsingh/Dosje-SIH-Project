from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.inspector import Inspector
from app.schemas.inspector import InspectorCreate, InspectorResponse


router = APIRouter(prefix="/inspectors", tags=["Inspectors"])


@router.post("", response_model=InspectorResponse, status_code=status.HTTP_201_CREATED)
def create_inspector(
    inspector_data: InspectorCreate,
    db: Session = Depends(get_db),
) -> Inspector:
    inspector_id = inspector_data.normalized_inspector_id
    inspector_name = inspector_data.normalized_inspector_name

    if not inspector_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="inspector_id cannot be blank")
    if not inspector_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="inspector_name cannot be blank",
        )

    existing = db.scalar(
        select(Inspector).where(Inspector.inspector_id == inspector_id).limit(1)
    )
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inspector ID already exists",
        )

    inspector = Inspector(
        inspector_id=inspector_id,
        inspector_name=inspector_name,
        is_active=inspector_data.is_active,
    )
    db.add(inspector)
    try:
        db.commit()
        db.refresh(inspector)
        return inspector
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create inspector",
        )


@router.get("", response_model=list[InspectorResponse])
def list_inspectors(
    is_active: bool | None = None,
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[Inspector]:
    statement = select(Inspector).order_by(Inspector.created_at.desc(), Inspector.id.desc())
    if is_active is not None:
        statement = statement.where(Inspector.is_active.is_(is_active))
    statement = statement.limit(limit).offset(offset)
    return list(db.scalars(statement).all())
