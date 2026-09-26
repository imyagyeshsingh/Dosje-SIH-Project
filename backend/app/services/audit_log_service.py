from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.audit_log import AuditLog


def create_audit_log(
    *,
    db: Session,
    project_id: int | None = None,
    entity_type: str,
    entity_id: int | None = None,
    action: str,
    actor_id: str | None = None,
    actor_name: str | None = None,
    details: str | None = None,
) -> AuditLog:
    record = AuditLog(
        project_id=project_id,
        entity_type=entity_type.strip(),
        entity_id=entity_id,
        action=action.strip(),
        actor_id=(actor_id.strip() if actor_id and actor_id.strip() else None),
        actor_name=(actor_name.strip() if actor_name and actor_name.strip() else None),
        details=(details.strip() if details and details.strip() else None),
        created_at=datetime.now(timezone.utc),
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return record
