# AI Integration Boundary & Contract Specification

## Overview

This document specifies the integration boundary between the DoSJE SIH FastAPI Backend and the external AI/ML detection pipeline (owned by Khushboo).

```
Khushboo AI/ML Pipeline (Simulated / External Producer)
           │
           │ HTTP POST /ai/detection
           ▼
FastAPI AI Ingestion Router (app/routers/ai.py)
           │
           ├─► Schema Validation & Normalization (app/schemas/ai_detection.py)
           │     (Normalizes aliases to canonical activity tokens)
           │
           ├─► PostgreSQL Persistence (ai_detections table)
           │
           ├─► Audit Logging (audit_logs table: entity_type="AI_DETECTION", action="CREATED")
           │
           ├─► Automated Downstream Monitoring & Alert Evaluation (app/services/alert_service.py)
           │     ├─► Project Risk Recalculation (app/routers/risk.py)
           │     ├─► Attendance Anomaly Evaluation (app/models/attendance.py)
           │     ├─► AI Activity / Suspicious Alert Triggering
           │     ├─► Notification Generation (app/services/notification_service.py)
           │     └─► Alert Audit Logging (audit_logs table: entity_type="ALERT")
           │
           ▼
Yagyesh Frontend Dashboard (Real-time monitoring, alerts, attendance, and risk views)
```

---

## Current Backend Boundary

1. **Passive Ingestion Boundary:**
   The backend provides the ingestion endpoint `POST /ai/detection`. The backend does not initiate outbound HTTP requests to an external AI service, nor does it run computer vision/inference models internally. It acts as an authoritative, validated receiver for inference telemetry.
2. **Synchronous Validation & Persistence:**
   Incoming detections are validated against Pydantic constraints, checked for valid project and camera associations, normalized, and saved to PostgreSQL.
3. **Automated Monitoring Hook:**
   Upon committing the detection, the backend creates an `AI_DETECTION` audit log entry and invokes `generate_project_alerts()` to evaluate whether the new detection triggers risk updates, activity alerts (e.g. `SUSPICIOUS`, `HIGH`, or `NO_ACTIVITY`), or attendance alerts.

---

## API Contract: `POST /ai/detection`

### Request Fields

| Field | Type | Required | Description & Constraints |
| :--- | :--- | :--- | :--- |
| `project_id` | `integer` | **Yes** | Project identifier (`gt=0`). Must exist in `projects` table. |
| `camera_id` | `integer` | **Yes** | Camera identifier (`gt=0`). Must exist in `cameras` table and belong to `project_id`. |
| `people_detected` | `integer` | **Yes** | Headcount detected (`ge=0`). |
| `activity` | `string` | **Yes** | Activity description (1 to 50 chars). Normalized to canonical activity tokens. |
| `confidence` | `float` | **Yes** | Detection confidence score (`0.0 <= confidence <= 1.0`). |
| `timestamp` | `datetime` | **Yes** | ISO 8601 UTC timestamp of the frame/event capture. |

### Response Fields (`HTTP 201 Created`)

| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | `integer` | Server-assigned primary key |
| `project_id` | `integer` | Associated project ID |
| `camera_id` | `integer` | Associated camera ID |
| `people_detected` | `integer` | Recorded headcount |
| `activity` | `string` | Canonical activity token stored in database |
| `confidence` | `float` | Recorded confidence (0.0 to 1.0) |
| `timestamp` | `datetime` | Detection event timestamp |
| `created_at` | `datetime` | Server record creation timestamp |

### HTTP Status Codes
* `201 Created`: Detection successfully persisted and evaluated.
* `400 Bad Request`: Camera does not belong to the supplied project.
* `404 Not Found`: Project or camera does not exist.
* `422 Unprocessable Entity`: Field validation failed (e.g. negative people count, confidence out of range, empty/unsupported activity).

---

## Canonical Activity Values & Aliases

To bridge free-form labels from CV models and demo payloads with backend risk/alert rules, incoming activity strings are normalized at ingestion:

| Canonical Token | Downstream Risk Weight Value | Alert Triggered | Supported Incoming Aliases (Case-Insensitive) |
| :--- | :---: | :---: | :--- |
| `NORMAL` | 0 | None | `"NORMAL"`, `"WORKERS PRESENT"`, `"CONSTRUCTION ACTIVITY DETECTED"`, `"NORMAL ACTIVITY"` |
| `LOW` | 30 | None | `"LOW"`, `"LOW ACTIVITY"` |
| `NO_ACTIVITY` | 60 | `MEDIUM` (`AI_ACTIVITY`) | `"NO_ACTIVITY"`, `"NO ACTIVITY"`, `"NONE"`, `"INACTIVE"` |
| `HIGH` | 70 | `HIGH` (`AI_ACTIVITY`) | `"HIGH"`, `"HIGH ACTIVITY"` |
| `SUSPICIOUS` | 100 | `HIGH` (`AI_ACTIVITY`) | `"SUSPICIOUS"`, `"SUSPICIOUS ACTIVITY"` |

*Note:* Ambiguous or unmapped activity strings are rejected with `HTTP 422 Unprocessable Entity` to prevent undefined risk behaviors.

---

## Idempotency & Duplicate Handling Limitation

* **Current Status:** The current ingestion endpoint is **not idempotent**.
* **Rationale:** The repository currently has no external AI `event_id` or `detection_id`. We deliberately avoid imposing a composite database uniqueness constraint on `(project_id, camera_id, timestamp)` because high-frequency video analytics pipelines may legitimately emit distinct detections within the same timestamp second.
* **Future Expectation:** Once Khushboo's final producer contract is established, an explicit external `event_id` or idempotency token should be introduced in the request payload and backed by a database unique constraint.

---

## Contract Status & Khushboo Integration Readiness

* The backend does **not** assume or mock an external Khushboo microservice URL.
* When Khushboo's pipeline is ready, it only needs to POST JSON payloads matching the contract to `/ai/detection`.
* All downstream attendance aggregation, multi-factor risk scoring, alert generation, and notification delivery will automatically operate without additional backend changes.

