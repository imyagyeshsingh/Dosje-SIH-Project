import threading
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from starlette.websockets import WebSocketDisconnect

from app.database import Base, get_db
from app.main import app
from app.models.project import Project
from app.models.video_session import VideoSession


@pytest.fixture
def client_and_db():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    Base.metadata.create_all(bind=engine)

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client, TestingSessionLocal
    app.dependency_overrides.clear()
    Base.metadata.drop_all(bind=engine)


def create_project(session, project_name: str = "Project A") -> Project:
    project = Project(
        project_name=project_name,
        project_code=f"SIG-{project_name.lower().replace(' ', '-')}-{datetime.now(timezone.utc).timestamp()}",
        status="ACTIVE",
        progress=50,
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def create_video_session(session, project_id: int, session_id: str = "550e8400-e29b-41d4-a716-446655440100") -> VideoSession:
    video_session = VideoSession(
        project_id=project_id,
        session_id=session_id,
        status="CREATED",
    )
    session.add(video_session)
    session.commit()
    session.refresh(video_session)
    return video_session


def receive_json_with_timeout(websocket, timeout: float = 2.0):
    result = {}

    def reader() -> None:
        try:
            result["value"] = websocket.receive_json()
        except Exception as exc:  # pragma: no cover - used in tests only
            result["error"] = exc

    thread = threading.Thread(target=reader, daemon=True)
    thread.start()
    thread.join(timeout)

    if "value" in result:
        return result["value"]
    if "error" in result:
        raise result["error"]
    raise TimeoutError("Timed out waiting for websocket message")


def test_video_signaling_route_exists():
    route_paths = {
        getattr(route, "path", None)
        for route in app.router.routes
        if hasattr(route, "path")
    }
    assert "/ws/video/{session_id}" in route_paths


def test_video_signaling_rejects_invalid_session_id(client_and_db):
    client, _ = client_and_db
    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect("/ws/video/not-a-valid-session") as websocket:
            websocket.receive_text()


def test_video_signaling_allows_officer_and_representative_join(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        session = create_video_session(db, project.id, "550e8400-e29b-41d4-a716-446655440101")

        with client.websocket_connect(f"/ws/video/{session.session_id}") as officer_ws:
            officer_ws.send_json({"type": "join", "role": "officer"})
            assert receive_json_with_timeout(officer_ws)["type"] == "participant-joined"

            with client.websocket_connect(f"/ws/video/{session.session_id}") as representative_ws:
                representative_ws.send_json({"type": "join", "role": "representative"})
                rep_message = receive_json_with_timeout(representative_ws)
                assert rep_message["type"] == "participant-joined"
                assert rep_message["role"] == "representative"

                officer_message = receive_json_with_timeout(officer_ws)
                assert officer_message["type"] == "participant-joined"
                assert officer_message["role"] == "representative"

                db.refresh(session)
                assert session.status == "ACTIVE"
    finally:
        db.close()


def test_video_signaling_rejects_third_participant(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        session = create_video_session(db, project.id, "550e8400-e29b-41d4-a716-446655440102")

        with client.websocket_connect(f"/ws/video/{session.session_id}") as officer_ws:
            officer_ws.send_json({"type": "join", "role": "officer"})
            receive_json_with_timeout(officer_ws)

            with client.websocket_connect(f"/ws/video/{session.session_id}") as representative_ws:
                representative_ws.send_json({"type": "join", "role": "representative"})
                receive_json_with_timeout(representative_ws)
                receive_json_with_timeout(officer_ws)

                with client.websocket_connect(f"/ws/video/{session.session_id}") as third_ws:
                    third_ws.send_json({"type": "join", "role": "officer"})
                    error_message = receive_json_with_timeout(third_ws)
                    assert error_message["type"] == "error"
                    assert "full" in error_message["message"].lower()
    finally:
        db.close()


def test_video_signaling_rejects_duplicate_roles(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        session = create_video_session(db, project.id, "550e8400-e29b-41d4-a716-446655440103")

        with client.websocket_connect(f"/ws/video/{session.session_id}") as first_ws:
            first_ws.send_json({"type": "join", "role": "officer"})
            receive_json_with_timeout(first_ws)

            with client.websocket_connect(f"/ws/video/{session.session_id}") as second_ws:
                second_ws.send_json({"type": "join", "role": "officer"})
                message = receive_json_with_timeout(second_ws)
                assert message["type"] == "error"
                assert "already connected" in message["message"].lower()
    finally:
        db.close()


def test_video_signaling_relay_offer_to_other_participant(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        session = create_video_session(db, project.id, "550e8400-e29b-41d4-a716-446655440104")

        with client.websocket_connect(f"/ws/video/{session.session_id}") as officer_ws:
            officer_ws.send_json({"type": "join", "role": "officer"})
            receive_json_with_timeout(officer_ws)

            with client.websocket_connect(f"/ws/video/{session.session_id}") as representative_ws:
                representative_ws.send_json({"type": "join", "role": "representative"})
                receive_json_with_timeout(representative_ws)
                receive_json_with_timeout(officer_ws)

                officer_ws.send_json({"type": "offer", "sdp": "offer-sdp"})
                received = receive_json_with_timeout(representative_ws)
                assert received == {"type": "offer", "sdp": "offer-sdp"}

                with pytest.raises(TimeoutError):
                    receive_json_with_timeout(officer_ws, timeout=0.5)
    finally:
        db.close()


def test_video_signaling_relay_answer_and_ice_candidate(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        session = create_video_session(db, project.id, "550e8400-e29b-41d4-a716-446655440105")

        with client.websocket_connect(f"/ws/video/{session.session_id}") as officer_ws:
            officer_ws.send_json({"type": "join", "role": "officer"})
            receive_json_with_timeout(officer_ws)

            with client.websocket_connect(f"/ws/video/{session.session_id}") as representative_ws:
                representative_ws.send_json({"type": "join", "role": "representative"})
                receive_json_with_timeout(representative_ws)
                receive_json_with_timeout(officer_ws)

                representative_ws.send_json({"type": "answer", "sdp": "answer-sdp"})
                assert receive_json_with_timeout(officer_ws) == {"type": "answer", "sdp": "answer-sdp"}

                representative_ws.send_json(
                    {
                        "type": "ice-candidate",
                        "candidate": {"candidate": "candidate:1", "sdpMid": "0", "sdpMLineIndex": 0},
                    }
                )
                msg = receive_json_with_timeout(officer_ws)
                assert msg["type"] == "ice-candidate"
                assert msg["candidate"]["candidate"] == "candidate:1"
    finally:
        db.close()


def test_video_signaling_rejects_malformed_json_and_unsupported_message(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        session = create_video_session(db, project.id, "550e8400-e29b-41d4-a716-446655440106")

        with client.websocket_connect(f"/ws/video/{session.session_id}") as websocket:
            websocket.send_text('{bad json')
            assert receive_json_with_timeout(websocket)["type"] == "error"

            websocket.send_json({"type": "join", "role": "officer"})
            assert receive_json_with_timeout(websocket)["type"] == "participant-joined"

            websocket.send_json({"type": "ping"})
            error_message = receive_json_with_timeout(websocket)
            assert error_message["type"] == "error"
            assert "Unsupported signaling message type" in error_message["message"]
    finally:
        db.close()


def test_video_signaling_rejects_invalid_role(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        session = create_video_session(db, project.id, "550e8400-e29b-41d4-a716-446655440107")

        with client.websocket_connect(f"/ws/video/{session.session_id}") as websocket:
            websocket.send_json({"type": "join", "role": "observer"})
            message = receive_json_with_timeout(websocket)
            assert message["type"] == "error"
            assert message["message"] == "Invalid participant role"
    finally:
        db.close()


def test_video_signaling_leave_event_notifies_other_participant(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        session = create_video_session(db, project.id, "550e8400-e29b-41d4-a716-446655440108")

        with client.websocket_connect(f"/ws/video/{session.session_id}") as officer_ws:
            officer_ws.send_json({"type": "join", "role": "officer"})
            receive_json_with_timeout(officer_ws)

            with client.websocket_connect(f"/ws/video/{session.session_id}") as representative_ws:
                representative_ws.send_json({"type": "join", "role": "representative"})
                receive_json_with_timeout(representative_ws)
                receive_json_with_timeout(officer_ws)

                officer_ws.send_json({"type": "leave"})
                left_message = receive_json_with_timeout(representative_ws)
                assert left_message == {"type": "participant-left", "role": "officer"}
    finally:
        db.close()


def test_video_signaling_disconnect_cleanup_notifies_other_participant(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        session = create_video_session(db, project.id, "550e8400-e29b-41d4-a716-446655440109")

        with client.websocket_connect(f"/ws/video/{session.session_id}") as officer_ws:
            officer_ws.send_json({"type": "join", "role": "officer"})
            receive_json_with_timeout(officer_ws)

            with client.websocket_connect(f"/ws/video/{session.session_id}") as representative_ws:
                representative_ws.send_json({"type": "join", "role": "representative"})
                receive_json_with_timeout(representative_ws)
                receive_json_with_timeout(officer_ws)

                officer_ws.close()
                message = receive_json_with_timeout(representative_ws)
                assert message == {"type": "participant-left", "role": "officer"}
    finally:
        db.close()
