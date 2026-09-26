# Audit Logs

## Purpose

Audit Logs are a lightweight, append-only history for important backend actions. They are intentionally separate from the user-facing notification system.

## Fields

Each audit record stores:

- id
- project_id
- entity_type
- entity_id
- action
- actor_id
- actor_name
- details
- created_at

The model does not include a foreign key to a user or auth table because the current backend does not define a universal user model.

## Endpoints

- POST /audit-logs
- GET /audit-logs/{audit_log_id}
- GET /audit-logs
- GET /audit-logs/project/{project_id}

Supported list filters:

- project_id
- entity_type
- entity_id
- action
- actor_id
- limit

Records are returned newest-first by created_at desc, id desc.

## Append-only behavior

Audit log rows are intended to be append-only. The API exposes create and read operations only; there are no update or delete endpoints for historical audit records.

## Actor handling

actor_id and actor_name remain nullable. They are populated only when the existing operational flow already has a real inspection/officer or inspector identifier.

Examples include:

- inspection.officer_id
- inspection.officer_name
- inspector.inspector_id
- inspector.inspector_name

No fake user IDs, no authentication identifiers, and no invented actor values are created.

## Automatic event types currently implemented

The current backend creates audit records for these business events:

- INSPECTION / CREATED
- INSPECTION / ASSIGNED
- INSPECTION / RANDOMLY_ASSIGNED
- INSPECTION / STATUS_CHANGED
- ALERT / CREATED

## Relationship to notifications

Notifications remain operational and user-facing. Audit Logs are backend history. They are intentionally separate and do not replace the notification system.

## Limitations

- This backend does not include a universal authenticated user model.
- Audit logs are intentionally minimal and event-focused.
- The implementation does not add audit records for media uploads, CCTV uploads, AI ingestion, reports, location verification, or video sessions unless those flows are explicitly added in the future.
