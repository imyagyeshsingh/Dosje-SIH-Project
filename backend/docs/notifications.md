# Notifications (Task 17)

## Purpose

DoSJE keeps an in-app notification record for project events so the frontend can show an alert/notification feed and unread badge.

Notifications are **persistent rows in PostgreSQL (Neon)**, created **synchronously inside the existing request flow** that produced the event. There is no message broker, no background worker, no push provider and no notification WebSocket in this task.

## Notification model

Table: `notifications` (`app/models/notification.py`)

| Column | Type | Notes |
| --- | --- | --- |
| `id` | integer | primary key |
| `project_id` | integer | FK `projects.id`, not null, indexed |
| `recipient_id` | `varchar(100)` | nullable, indexed — see semantics below |
| `recipient_role` | `varchar(50)` | nullable, free text (no check constraint) |
| `notification_type` | `varchar(50)` | not null, checked values below |
| `severity` | `varchar(20)` | nullable, checked values below |
| `title` | `varchar(255)` | nullable |
| `message` | `varchar(500)` | not null, non-blank after trimming |
| `source` | `varchar(50)` | not null, producing subsystem |
| `alert_id` | integer | FK `alerts.id`, nullable, indexed |
| `inspection_id` | integer | FK `inspections.id`, nullable, indexed |
| `is_read` | boolean | not null, default `false` |
| `read_at` | timestamp with time zone | nullable, set when marked read |
| `created_at` | timestamp with time zone | server default `now()` |
| `updated_at` | timestamp with time zone | server default `now()`, `onupdate` |

Existing tables were not modified. The table is registered through `Base.metadata.create_all()` on application startup, so it is created on the next app start / test run.

### Notification types

`ALERT`, `INSPECTION`, `ASSIGNMENT`, `REPORT`, `VIDEO_SESSION`, `SYSTEM`

Only `ALERT`, `INSPECTION` and `ASSIGNMENT` have automatic hooks in this task. `REPORT`, `VIDEO_SESSION` and `SYSTEM` are accepted by the API for manual creation (and for future tasks).

### Severity

`LOW`, `MEDIUM`, `HIGH`, `CRITICAL` — nullable.

Automatic severities:

| Event | Severity |
| --- | --- |
| Alert notification | the alert's own severity |
| Inspection created (`ALERT_TRIGGERED` / `RANDOM` / `SCHEDULED` / `MANUAL`) | `HIGH` / `MEDIUM` / `LOW` / `LOW` |
| Inspection assigned | `MEDIUM` |
| Inspection `COMPLETED` / `CANCELLED` | `LOW` / `MEDIUM` |

## API endpoints

Prefix `/notifications`, tag `Notifications`.

| Method | Path | Description |
| --- | --- | --- |
| `POST` | `/notifications` | create a notification manually, returns `201` |
| `GET` | `/notifications/{notification_id}` | one notification, `404` if missing |
| `GET` | `/notifications` | list, newest first (`created_at DESC`, `id DESC`) |
| `GET` | `/notifications/project/{project_id}` | project notifications, newest first, `404` for unknown project |
| `GET` | `/notifications/summary` | `{ "total": n, "unread": n }` |
| `PUT` | `/notifications/{notification_id}/read` | mark one notification read |
| `PUT` | `/notifications/read-all` | mark matching notifications read |

### List filters (`GET /notifications`)

- `recipient_id`
- `recipient_role`
- `project_id`
- `notification_type`
- `is_read`
- `limit` (1–500)

`GET /notifications/summary` accepts `recipient_id`, `recipient_role` and `project_id`.
`PUT /notifications/read-all` accepts `recipient_id`, `recipient_role` and `project_id` and returns `{ "marked_read": n }`. With no filters it marks every unread notification.

`POST /notifications` validates that `project_id` exists and, when supplied, that `alert_id` / `inspection_id` exist and belong to that project (`404` when missing, `400` when they belong to another project). Manual creation never de-duplicates.

## `recipient_id` semantics

This backend has **no user table, no accounts and no authentication/RBAC**; that is owned by the frontend teammate. Therefore:

- `recipient_id` is a nullable free-text identifier (`varchar(100)`) with **no foreign key**.
- Today the automatic hooks fill it with the existing inspector identifier (`inspection.officer_id`, i.e. `inspectors.inspector_id`).
- When an event has no real recipient identifier available, `recipient_id` is stored as `NULL` instead of inventing a fake user id.
- A `NULL` recipient means "project-level / broadcast" and is a valid notification (for example a newly created random inspection that is not assigned yet).
- `recipient_role` is nullable free text with no check constraint, so frontend role names can be used later without a schema change.

## Read / unread behaviour

- New notifications are stored with `is_read = false` and `read_at = NULL`.
- `PUT /notifications/{notification_id}/read` sets `is_read = true` and `read_at = now()` (UTC). Calling it again keeps the **first** `read_at` value (idempotent).
- `PUT /notifications/read-all` sets `read_at` once for every matching unread row.
- `GET /notifications/summary` returns the unread count for badge display.

## Automatic notification triggers

| Trigger | Endpoint / function | Notification |
| --- | --- | --- |
| Newly generated alerts | `POST /alerts/generate/{project_id}` → `generate_project_alerts()` | `ALERT`, `source=ALERT_ENGINE`, `alert_id` set, message/severity copied from the alert, `recipient_id = NULL` |
| Inspection created | `POST /inspections`, `POST /inspections/random`, `POST /inspections/from-alert/{alert_id}` | `INSPECTION`, `source=INSPECTION_ENGINE`, `inspection_id` set, `recipient_id = officer_id` when known |
| Inspection manually assigned | `POST /inspections/{inspection_id}/assign` | `ASSIGNMENT`, `source=ASSIGNMENT_ENGINE`, `recipient_id = officer_id` |
| Inspection randomly assigned | `POST /inspections/{inspection_id}/assign-random` | `ASSIGNMENT`, message "Inspection randomly assigned to ...", `recipient_id = officer_id` |
| Meaningful status change | `PUT /inspections/{inspection_id}/status` and `PUT /inspections/{inspection_id}` | `INSPECTION`, only for `COMPLETED` and `CANCELLED` (not `SCHEDULED`/`IN_PROGRESS`), message "Inspection status changed from X to Y" |

Not hooked in this task (by design): report events, geo-location verification results, video-session events, manual `POST /alerts` creation, unassignment.

### Duplicate prevention

- Alert notifications are created **only for the alerts returned by the existing `generate_project_alerts()` flow**, i.e. only for newly created alerts. Re-running the generation flow for an existing open alert does not create another notification.
- All hooks use a query-before-insert check on `(project_id, notification_type, source, message, recipient_id, alert_id/inspection_id)`. Repeating the same assignment or the same status change does not duplicate a notification.
- There is **no database unique constraint** for notification de-duplication.
- Existing alert de-duplication logic is unchanged.

## Important limitations

- No authentication, no RBAC, no user/account model, no Clerk integration was added. `recipient_id`/`recipient_role` are caller-supplied strings.
- No Firebase / FCM / APNs, no Redis, no Celery, no Kafka, no message broker, no notification WebSocket. The existing video-signaling WebSocket is untouched and must not be used for these notifications.
- Notifications are written in the same request as the triggering event (each hook commits the notification right after the existing business transaction).
- Inspection status rules, random inspection selection, automatic assignment behaviour and video-session behaviour are unchanged.
