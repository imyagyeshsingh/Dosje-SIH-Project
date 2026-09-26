import json
import logging
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.database import Base, engine, get_db
from app.models.ai_detection import AIDetection
from app.models.alert import Alert
from app.models.attendance import Attendance
from app.models.audit_log import AuditLog
from app.models.camera import Camera
from app.models.inspection import Inspection
from app.models.inspector import Inspector
from app.models.media import Media
from app.models.notification import Notification
from app.models.project import Project
from app.models.report import Report
from app.models.report_evidence_reference import ReportEvidenceReference
from app.models.user_role_whitelist import UserRoleWhitelist
from app.models.video_session import VideoSession
from app.routers.ai import router as ai_router
from app.routers.alerts import router as alerts_router
from app.routers.attendance import router as attendance_router
from app.routers.audit_logs import router as audit_logs_router
from app.routers.auth import router as auth_router
from app.routers.cctv import router as cctv_router
from app.routers.inspectors import router as inspectors_router
from app.routers.inspections import router as inspections_router
from app.routers.notifications import router as notifications_router
from app.routers.projects import router as projects_router
from app.routers.reports import router as reports_router
from app.routers.risk import router as risk_router
from app.routers.video_sessions import router as video_sessions_router
from app.services.video_signaling import (
    VALID_MESSAGE_TYPES,
    VALID_ROLES,
    activate_video_session_if_needed,
    end_video_session_if_needed,
    parse_signaling_message,
    signaling_manager,
)


logger = logging.getLogger(__name__)

app = FastAPI(title="DoSJE Real-Time Monitoring & Inspection System")
app.include_router(auth_router)
app.include_router(projects_router)
app.include_router(cctv_router)
app.include_router(ai_router)
app.include_router(attendance_router)
app.include_router(alerts_router)
app.include_router(audit_logs_router)
app.include_router(inspectors_router)
app.include_router(inspections_router)
app.include_router(notifications_router)
app.include_router(reports_router)
app.include_router(risk_router)
app.include_router(video_sessions_router)


def get_websocket_db_session():
    override = app.dependency_overrides.get(get_db)
    generator = override() if override else get_db()
    return next(generator)


@app.websocket("/ws/video/{session_id}")
async def video_signaling_session(websocket: WebSocket, session_id: str) -> None:
    await websocket.accept()

    db = get_websocket_db_session()
    try:
        video_session = db.query(VideoSession).filter(VideoSession.session_id == session_id).one_or_none()
        if video_session is None:
            await websocket.close(code=1008, reason="Session not found")
            return

        if video_session.status in {"ENDED", "CANCELLED"}:
            await websocket.close(code=1008, reason="Session is not joinable")
            return

        connected_role: str | None = None

        try:
            while True:
                raw_message = await websocket.receive_text()
                payload = parse_signaling_message(raw_message)
                if payload is None:
                    await websocket.send_json({"type": "error", "message": "Invalid JSON message"})
                    continue

                message_type = payload.get("type")
                if message_type == "join":
                    role = payload.get("role")
                    if role not in VALID_ROLES:
                        await websocket.send_json({"type": "error", "message": "Invalid participant role"})
                        continue

                    try:
                        signaling_manager.add_participant(session_id, role, websocket)
                    except ValueError as exc:
                        await websocket.send_json({"type": "error", "message": str(exc)})
                        await websocket.close(code=1008, reason=str(exc))
                        return

                    connected_role = role
                    if len(signaling_manager.get_session(session_id)) >= 2:
                        activate_video_session_if_needed(video_session, db)

                    await signaling_manager.notify_all(
                        session_id,
                        {"type": "participant-joined", "role": role},
                    )
                    continue

                if connected_role is None:
                    await websocket.send_json({"type": "error", "message": "Join before signaling messages"})
                    continue

                if message_type not in VALID_MESSAGE_TYPES:
                    await websocket.send_json({"type": "error", "message": "Unsupported signaling message type"})
                    continue

                if message_type in {"offer", "answer", "ice-candidate"}:
                    await signaling_manager.relay_to_other(session_id, connected_role, payload)
                    continue

                if message_type == "leave":
                    signaling_manager.remove_participant(session_id, connected_role)
                    await signaling_manager.notify_all(
                        session_id,
                        {"type": "participant-left", "role": connected_role},
                        exclude_role=connected_role,
                    )
                    await websocket.close(code=1000)
                    return

                if message_type == "end":
                    end_video_session_if_needed(video_session, db)
                    await signaling_manager.notify_all(
                        session_id,
                        {"type": "ended", "role": connected_role},
                        exclude_role=connected_role,
                    )
                    signaling_manager.remove_participant(session_id, connected_role)
                    await websocket.close(code=1000)
                    return

        except WebSocketDisconnect:
            if connected_role:
                signaling_manager.remove_participant(session_id, connected_role)
                await signaling_manager.notify_all(
                    session_id,
                    {"type": "participant-left", "role": connected_role},
                    exclude_role=connected_role,
                )
            return
    finally:
        db.close()


@app.on_event("startup")
def create_database_tables() -> None:
    try:
        Base.metadata.create_all(bind=engine)
    except SQLAlchemyError:
        logger.exception("Failed to create database tables during startup")


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/db-health")
def database_health() -> dict[str, str]:
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except SQLAlchemyError:
        raise HTTPException(status_code=500, detail="Database connection failed")

    return {"database": "connected"}
