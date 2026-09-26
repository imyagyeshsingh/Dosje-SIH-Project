import json
import os
from datetime import datetime, timezone
from typing import Any

from fastapi import WebSocket
from sqlalchemy.orm import Session

from app.models.video_session import VideoSession

VALID_ROLES = {"officer", "representative"}
VALID_MESSAGE_TYPES = {"join", "offer", "answer", "ice-candidate", "leave", "end"}


class VideoSignalingManager:
    def __init__(self) -> None:
        self.sessions: dict[str, dict[str, WebSocket]] = {}

    def get_session(self, session_id: str) -> dict[str, WebSocket]:
        return self.sessions.setdefault(session_id, {})

    def add_participant(self, session_id: str, role: str, websocket: WebSocket) -> None:
        if role not in VALID_ROLES:
            raise ValueError("Invalid participant role")

        session = self.get_session(session_id)
        if len(session) >= 2:
            raise ValueError("Video session is full")

        if role in session:
            raise ValueError("Participant role is already connected")

        session[role] = websocket

    def remove_participant(self, session_id: str, role: str) -> None:
        session = self.sessions.get(session_id)
        if not session:
            return

        session.pop(role, None)
        if not session:
            self.sessions.pop(session_id, None)

    @staticmethod
    def get_other_role(role: str) -> str:
        return "representative" if role == "officer" else "officer"

    async def relay_to_other(self, session_id: str, sender_role: str, payload: dict[str, Any]) -> None:
        session = self.sessions.get(session_id, {})
        receiver_role = self.get_other_role(sender_role)
        receiver = session.get(receiver_role)
        if receiver is not None:
            try:
                await receiver.send_json(payload)
            except RuntimeError:
                pass

    async def notify_all(self, session_id: str, payload: dict[str, Any], *, exclude_role: str | None = None) -> None:
        session = self.sessions.get(session_id, {})
        for role, websocket in session.items():
            if exclude_role is not None and role == exclude_role:
                continue
            try:
                await websocket.send_json(payload)
            except RuntimeError:
                pass

    async def disconnect_role(self, session_id: str, role: str) -> None:
        self.remove_participant(session_id, role)
        if not self.sessions.get(session_id):
            return

        other_role = self.get_other_role(role)
        if other_role in self.sessions.get(session_id, {}):
            await self.notify_all(
                session_id,
                {"type": "participant-left", "role": role},
                exclude_role=role,
            )


signaling_manager = VideoSignalingManager()


def get_webrtc_ice_servers() -> list[dict[str, list[str]]]:
    stun_server = os.getenv("WEBRTC_STUN_SERVER")
    ice_servers: list[dict[str, list[str]]] = []
    if stun_server:
        ice_servers.append({"urls": [stun_server]})
    return ice_servers


def activate_video_session_if_needed(video_session: VideoSession, db: Session) -> None:
    if video_session.status == "CREATED" and len(signaling_manager.get_session(video_session.session_id)) >= 2:
        if video_session.started_at is None:
            video_session.started_at = datetime.now(timezone.utc)
        video_session.status = "ACTIVE"
        db.commit()
        db.refresh(video_session)


def end_video_session_if_needed(video_session: VideoSession, db: Session) -> None:
    if video_session.status == "ACTIVE":
        if video_session.ended_at is None:
            video_session.ended_at = datetime.now(timezone.utc)
        video_session.status = "ENDED"
        db.commit()
        db.refresh(video_session)


def parse_signaling_message(raw_message: str) -> dict[str, Any] | None:
    try:
        payload = json.loads(raw_message)
    except json.JSONDecodeError:
        return None

    if not isinstance(payload, dict):
        return None
    return payload
