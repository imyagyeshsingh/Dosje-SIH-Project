from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.audit_log import AuditLog
from app.schemas.audit_log import AuditLogCreate, AuditLogResponse
from app.services.audit_log_service import create_audit_log


router = APIRouter(prefix="/audit-logs", tags=["Audit Logs"])


def get_audit_log_or_404(audit_log_id: int, db: Session) -> AuditLog:
    audit_log = db.get(AuditLog, audit_log_id)
    if audit_log is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Audit log not found",
        )
    return audit_log


@router.post("", response_model=AuditLogResponse, status_code=status.HTTP_201_CREATED)
def create_audit_log_entry(
    audit_log_data: AuditLogCreate,
    db: Session = Depends(get_db),
) -> AuditLog:
    try:
        return create_audit_log(
            db=db,
            project_id=audit_log_data.project_id,
            entity_type=audit_log_data.entity_type,
            entity_id=audit_log_data.entity_id,
            action=audit_log_data.action,
            actor_id=audit_log_data.actor_id,
            actor_name=audit_log_data.actor_name,
            details=audit_log_data.details,
        )
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create audit log",
        )


@router.get("/project/{project_id}", response_model=list[AuditLogResponse])
def list_project_audit_logs(
    project_id: int,
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[AuditLog]:
    statement = (
        select(AuditLog)
        .where(AuditLog.project_id == project_id)
        .order_by(AuditLog.created_at.desc(), AuditLog.id.desc())
        .limit(limit)
        .offset(offset)
    )
    return list(db.scalars(statement).all())


@router.get("", response_model=list[AuditLogResponse])
def list_audit_logs(
    project_id: int | None = None,
    entity_type: str | None = None,
    entity_id: int | None = None,
    action: str | None = None,
    actor_id: str | None = None,
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[AuditLog]:
    statement = select(AuditLog).order_by(AuditLog.created_at.desc(), AuditLog.id.desc())

    if project_id is not None:
        statement = statement.where(AuditLog.project_id == project_id)
    if entity_type is not None:
        statement = statement.where(AuditLog.entity_type == entity_type)
    if entity_id is not None:
        statement = statement.where(AuditLog.entity_id == entity_id)
    if action is not None:
        statement = statement.where(AuditLog.action == action)
    if actor_id is not None:
        statement = statement.where(AuditLog.actor_id == actor_id)
    statement = statement.limit(limit).offset(offset)

    return list(db.scalars(statement).all())


@router.get("/{audit_log_id}", response_model=AuditLogResponse)
def get_audit_log(
    audit_log_id: int,
    db: Session = Depends(get_db),
) -> AuditLog:
    return get_audit_log_or_404(audit_log_id, db)
