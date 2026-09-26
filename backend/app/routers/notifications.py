from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.alert import Alert
from app.models.inspection import Inspection
from app.models.notification import Notification
from app.models.project import Project
from app.schemas.notification import (
    NotificationBulkReadResponse,
    NotificationCreate,
    NotificationResponse,
    NotificationSummaryResponse,
    NotificationType,
)
from app.services.notification_service import (
    create_notification as create_notification_record,
    mark_all_notifications_read,
    mark_notification_read,
)


router = APIRouter(prefix="/notifications", tags=["Notifications"])


def get_project_or_404(project_id: int, db: Session) -> Project:
    project = db.get(Project, project_id)
    if project is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    return project


def get_notification_or_404(notification_id: int, db: Session) -> Notification:
    notification = db.get(Notification, notification_id)
    if notification is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found"
        )
    return notification


def validate_notification_links(
    project_id: int,
    alert_id: int | None,
    inspection_id: int | None,
    db: Session,
) -> None:
    get_project_or_404(project_id, db)

    if alert_id is not None:
        alert = db.get(Alert, alert_id)
        if alert is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Alert not found")
        if alert.project_id != project_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Alert does not belong to the supplied project",
            )

    if inspection_id is not None:
        inspection = db.get(Inspection, inspection_id)
        if inspection is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Inspection not found"
            )
        if inspection.project_id != project_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Inspection does not belong to the supplied project",
            )


def build_notification_filters(
    *,
    recipient_id: str | None = None,
    recipient_role: str | None = None,
    project_id: int | None = None,
    notification_type: str | None = None,
    is_read: bool | None = None,
) -> list:
    filters = []
    if recipient_id is not None:
        filters.append(Notification.recipient_id == recipient_id)
    if recipient_role is not None:
        filters.append(Notification.recipient_role == recipient_role)
    if project_id is not None:
        filters.append(Notification.project_id == project_id)
    if notification_type is not None:
        filters.append(Notification.notification_type == notification_type)
    if is_read is not None:
        filters.append(Notification.is_read.is_(is_read))
    return filters


@router.post("", response_model=NotificationResponse, status_code=status.HTTP_201_CREATED)
def create_notification(
    notification_data: NotificationCreate,
    db: Session = Depends(get_db),
) -> Notification:
    validate_notification_links(
        notification_data.project_id,
        notification_data.alert_id,
        notification_data.inspection_id,
        db,
    )

    try:
        notification = create_notification_record(
            db=db,
            project_id=notification_data.project_id,
            notification_type=notification_data.notification_type.value,
            message=notification_data.message,
            source=notification_data.source,
            recipient_id=notification_data.recipient_id,
            recipient_role=notification_data.recipient_role,
            severity=(
                notification_data.severity.value
                if notification_data.severity is not None
                else None
            ),
            title=notification_data.title,
            alert_id=notification_data.alert_id,
            inspection_id=notification_data.inspection_id,
            dedupe=False,
        )
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save notification",
        )
    return notification


@router.get("/summary", response_model=NotificationSummaryResponse)
def get_notification_summary(
    recipient_id: str | None = None,
    recipient_role: str | None = None,
    project_id: int | None = None,
    db: Session = Depends(get_db),
) -> NotificationSummaryResponse:
    filters = build_notification_filters(
        recipient_id=recipient_id,
        recipient_role=recipient_role,
        project_id=project_id,
    )

    total_statement = select(func.count()).select_from(Notification)
    unread_statement = (
        select(func.count())
        .select_from(Notification)
        .where(Notification.is_read.is_(False))
    )
    if filters:
        total_statement = total_statement.where(*filters)
        unread_statement = unread_statement.where(*filters)

    total = db.scalar(total_statement) or 0
    unread = db.scalar(unread_statement) or 0

    return NotificationSummaryResponse(total=int(total), unread=int(unread))


@router.get("/project/{project_id}", response_model=list[NotificationResponse])
def list_project_notifications(
    project_id: int,
    db: Session = Depends(get_db),
) -> list[Notification]:
    get_project_or_404(project_id, db)

    statement = (
        select(Notification)
        .where(Notification.project_id == project_id)
        .order_by(Notification.created_at.desc(), Notification.id.desc())
    )
    return list(db.scalars(statement).all())


@router.put("/read-all", response_model=NotificationBulkReadResponse)
def mark_all_as_read(
    recipient_id: str | None = None,
    recipient_role: str | None = None,
    project_id: int | None = None,
    db: Session = Depends(get_db),
) -> NotificationBulkReadResponse:
    try:
        marked_read = mark_all_notifications_read(
            db,
            recipient_id=recipient_id,
            recipient_role=recipient_role,
            project_id=project_id,
        )
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to mark notifications as read",
        )
    return NotificationBulkReadResponse(marked_read=marked_read)


@router.get("", response_model=list[NotificationResponse])
def list_notifications(
    recipient_id: str | None = None,
    recipient_role: str | None = None,
    project_id: int | None = None,
    notification_type: NotificationType | None = None,
    is_read: bool | None = None,
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[Notification]:
    filters = build_notification_filters(
        recipient_id=recipient_id,
        recipient_role=recipient_role,
        project_id=project_id,
        notification_type=(
            notification_type.value if notification_type is not None else None
        ),
        is_read=is_read,
    )

    statement = select(Notification).order_by(
        Notification.created_at.desc(), Notification.id.desc()
    )
    if filters:
        statement = statement.where(*filters)
    statement = statement.limit(limit).offset(offset)

    return list(db.scalars(statement).all())


@router.get("/{notification_id}", response_model=NotificationResponse)
def get_notification(notification_id: int, db: Session = Depends(get_db)) -> Notification:
    return get_notification_or_404(notification_id, db)


@router.put("/{notification_id}/read", response_model=NotificationResponse)
def mark_notification_as_read(
    notification_id: int,
    db: Session = Depends(get_db),
) -> Notification:
    notification = get_notification_or_404(notification_id, db)
    try:
        return mark_notification_read(notification, db)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to mark notification as read",
        )
