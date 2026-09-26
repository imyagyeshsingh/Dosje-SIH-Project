"""Persistent in-app notification helpers.

Notifications are stored in PostgreSQL (Neon) through the existing SQLAlchemy
session and are created synchronously inside the request flow. There is no
message broker, no background worker and no push provider in this task.

The helper functions below commit the session they receive, matching the
existing convention in ``app.services.alert_service.generate_project_alerts``.
"""

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.alert import Alert
from app.models.inspection import Inspection
from app.models.notification import Notification

NOTIFICATION_SOURCE_ALERTS = "ALERT_ENGINE"
NOTIFICATION_SOURCE_INSPECTIONS = "INSPECTION_ENGINE"
NOTIFICATION_SOURCE_ASSIGNMENTS = "ASSIGNMENT_ENGINE"

INSPECTION_CREATED_SEVERITY = {
    "ALERT_TRIGGERED": "HIGH",
    "RANDOM": "MEDIUM",
    "SCHEDULED": "LOW",
    "MANUAL": "LOW",
}

INSPECTION_STATUS_SEVERITY = {
    "COMPLETED": "LOW",
    "CANCELLED": "MEDIUM",
}

# Only terminal inspection status changes produce a notification.
INSPECTION_STATUS_NOTIFICATION_TARGETS = {"COMPLETED", "CANCELLED"}

ASSIGNMENT_SEVERITY = "MEDIUM"


def _notification_exists(
    db: Session,
    *,
    project_id: int,
    notification_type: str,
    source: str,
    message: str,
    recipient_id: str | None = None,
    alert_id: int | None = None,
    inspection_id: int | None = None,
) -> bool:
    """Query-before-insert duplicate check (no database unique constraint)."""
    statement = (
        select(Notification.id)
        .where(
            Notification.project_id == project_id,
            Notification.notification_type == notification_type,
            Notification.source == source,
            Notification.message == message,
        )
        .limit(1)
    )

    if alert_id is not None:
        statement = statement.where(Notification.alert_id == alert_id)
    if inspection_id is not None:
        statement = statement.where(Notification.inspection_id == inspection_id)
    if recipient_id is None:
        statement = statement.where(Notification.recipient_id.is_(None))
    else:
        statement = statement.where(Notification.recipient_id == recipient_id)

    return db.scalar(statement) is not None


def create_notification(
    *,
    db: Session,
    project_id: int,
    notification_type: str,
    message: str,
    source: str,
    recipient_id: str | None = None,
    recipient_role: str | None = None,
    severity: str | None = None,
    title: str | None = None,
    alert_id: int | None = None,
    inspection_id: int | None = None,
    dedupe: bool = True,
) -> Notification | None:
    """Persist a notification.

    Returns ``None`` when ``dedupe`` is enabled and an equivalent notification
    already exists. Commits and refreshes the created row on success.
    """
    if dedupe and _notification_exists(
        db,
        project_id=project_id,
        notification_type=notification_type,
        source=source,
        message=message,
        recipient_id=recipient_id,
        alert_id=alert_id,
        inspection_id=inspection_id,
    ):
        return None

    notification = Notification(
        project_id=project_id,
        recipient_id=recipient_id,
        recipient_role=recipient_role,
        notification_type=notification_type,
        severity=severity,
        title=title,
        message=message,
        source=source,
        alert_id=alert_id,
        inspection_id=inspection_id,
        is_read=False,
    )
    db.add(notification)
    db.commit()
    db.refresh(notification)
    return notification


def notify_alert(
    alert: Alert,
    db: Session,
    *,
    recipient_id: str | None = None,
    recipient_role: str | None = None,
) -> Notification | None:
    """Create the notification for a newly generated alert."""
    return create_notification(
        db=db,
        project_id=alert.project_id,
        notification_type="ALERT",
        severity=alert.severity,
        title=f"{alert.alert_type} alert",
        message=alert.message,
        source=NOTIFICATION_SOURCE_ALERTS,
        recipient_id=recipient_id,
        recipient_role=recipient_role,
        alert_id=alert.id,
    )


def notify_inspection_created(
    inspection: Inspection,
    db: Session,
    *,
    recipient_id: str | None = None,
    recipient_role: str | None = None,
) -> Notification | None:
    """Create the notification for a newly created inspection.

    ``recipient_id`` defaults to the inspection officer when the existing flow
    already knows one; otherwise the notification is stored with a null
    recipient (no identifier is invented).
    """
    recipient = inspection.officer_id if recipient_id is None else recipient_id
    return create_notification(
        db=db,
        project_id=inspection.project_id,
        notification_type="INSPECTION",
        severity=INSPECTION_CREATED_SEVERITY.get(inspection.inspection_type),
        title=f"{inspection.inspection_type} inspection created",
        message=f"New {inspection.inspection_type} inspection created",
        source=NOTIFICATION_SOURCE_INSPECTIONS,
        recipient_id=recipient,
        recipient_role=recipient_role,
        inspection_id=inspection.id,
    )


def notify_inspection_assigned(
    inspection: Inspection,
    db: Session,
    *,
    random_assignment: bool = False,
    recipient_id: str | None = None,
    recipient_role: str | None = None,
) -> Notification | None:
    """Create the notification for an assignment done by the existing flows."""
    if inspection.assignment_status != "ASSIGNED":
        return None

    recipient = inspection.officer_id if recipient_id is None else recipient_id
    if recipient is None:
        return None

    assignee = inspection.officer_name or inspection.officer_id
    prefix = "Inspection randomly assigned to" if random_assignment else "Inspection assigned to"
    return create_notification(
        db=db,
        project_id=inspection.project_id,
        notification_type="ASSIGNMENT",
        severity=ASSIGNMENT_SEVERITY,
        title="Inspection assignment",
        message=f"{prefix} {assignee}",
        source=NOTIFICATION_SOURCE_ASSIGNMENTS,
        recipient_id=recipient,
        recipient_role=recipient_role,
        inspection_id=inspection.id,
    )


def notify_inspection_status_changed(
    inspection: Inspection,
    db: Session,
    *,
    previous_status: str,
    recipient_id: str | None = None,
    recipient_role: str | None = None,
) -> Notification | None:
    """Create the notification for a meaningful inspection status change."""
    if previous_status == inspection.status:
        return None
    if inspection.status not in INSPECTION_STATUS_NOTIFICATION_TARGETS:
        return None

    recipient = inspection.officer_id if recipient_id is None else recipient_id
    return create_notification(
        db=db,
        project_id=inspection.project_id,
        notification_type="INSPECTION",
        severity=INSPECTION_STATUS_SEVERITY.get(inspection.status),
        title=f"Inspection {inspection.status}",
        message=f"Inspection status changed from {previous_status} to {inspection.status}",
        source=NOTIFICATION_SOURCE_INSPECTIONS,
        recipient_id=recipient,
        recipient_role=recipient_role,
        inspection_id=inspection.id,
    )


def mark_notification_read(notification: Notification, db: Session) -> Notification:
    """Mark one notification as read, keeping the first read timestamp."""
    if not notification.is_read:
        notification.is_read = True
        notification.read_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(notification)
    return notification


def mark_all_notifications_read(
    db: Session,
    *,
    recipient_id: str | None = None,
    recipient_role: str | None = None,
    project_id: int | None = None,
) -> int:
    """Mark every matching unread notification as read and return the count."""
    statement = select(Notification).where(Notification.is_read.is_(False))
    if recipient_id is not None:
        statement = statement.where(Notification.recipient_id == recipient_id)
    if recipient_role is not None:
        statement = statement.where(Notification.recipient_role == recipient_role)
    if project_id is not None:
        statement = statement.where(Notification.project_id == project_id)

    unread_notifications = list(db.scalars(statement).all())
    if not unread_notifications:
        return 0

    read_at = datetime.now(timezone.utc)
    for notification in unread_notifications:
        notification.is_read = True
        notification.read_at = read_at

    db.commit()
    return len(unread_notifications)
