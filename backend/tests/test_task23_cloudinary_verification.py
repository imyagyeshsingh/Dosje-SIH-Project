"""
tests/test_task23_cloudinary_verification.py — Task 23: Real Cloudinary Integration & Verification Tests

Verifies:
1. Application successfully authenticates with real Cloudinary (ping).
2. Real Image Evidence upload to Cloudinary:
   - Validates resource_type == "image", storage_provider == "cloudinary"
   - Verifies returned public_id and secure URL
   - Confirms asset existence via Cloudinary Admin API
   - Verifies database persistence in `media` table matching Cloudinary metadata
   - Cleans up uploaded test asset from Cloudinary
3. Real Video Evidence upload to Cloudinary:
   - Validates resource_type == "video"
   - Verifies returned metadata and database persistence
   - Cleans up uploaded test video from Cloudinary
4. Real CCTV Manual Video upload to Cloudinary:
   - Validates endpoint POST /cctv/{camera_id}/media with real MP4
   - Verifies returned metadata and database persistence with camera_id
   - Cleans up uploaded test video from Cloudinary
5. Error handling on Cloudinary upload failure:
   - Ensures HTTP 502 Bad Gateway
   - Ensures no misleading/orphaned DB records are persisted
6. Error handling on DB commit failure after upload:
   - Ensures HTTP 500 and database rollback

Uses isolated FastAPI test fixture pattern to avoid the known ReportEvidenceReference mapper issue.
"""

import base64
from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import patch
from uuid import uuid4

import cloudinary
import cloudinary.api
import cloudinary.uploader
import pytest
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

load_dotenv()

from app.database import Base, get_db
from app.models.ai_detection import AIDetection
from app.models.alert import Alert
from app.models.camera import Camera
from app.models.inspection import Inspection
from app.models.inspector import Inspector
from app.models.media import Media
from app.models.notification import Notification
from app.models.project import Project
from app.models.report import Report
from app.models.video_session import VideoSession
from app.routers.cctv import router as cctv_router
from app.routers.inspections import router as inspections_router
from app.services.cloudinary_service import get_cloudinary_config, is_cloudinary_configured

# 16x16 valid PNG bytes (101 bytes)
TINY_PNG_BASE64 = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAACXBIWXMAAAABAAAAAQBPJcTWAAAAF0lEQVR4nGP8w0AaYCFR/aiGUQ1DSAMAZPEBOnXWok4AAAAASUVORK5CYII="
TINY_PNG_BYTES = base64.b64decode(TINY_PNG_BASE64)

# Tiny valid H.264 MP4 (0.52s, 1928 bytes)
TINY_MP4_BASE64 = (
    "AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAAA4ttZGF0AAACrgYF//+q3EXp"
    "vebZSLeWLNgg2SPu73gyNjQgLSBjb3JlIDE2NSByMzIyMiBiMzU2MDVhIC0gSC4yNjQvTVBFRy00IEFW"
    "QyBjb2RlYyAtIENvcHlsZWZ0IDIwMDMtMjAyNSAtIGh0dHA6Ly93d3cudmlkZW9sYW4ub3JnL3gyNjQu"
    "aHRtbCAtIG9wdGlvbnM6IGNhYmFjPTEgcmVmPTMgZGVibG9jaz0xOjA6MCBhbmFseXNlPTB4MzoweDEx"
    "MyBtZT1oZXggc3VibWU9NyBwc3k9MSBwc3lfcmQ9MS4wMDowLjAwIG1peGVkX3JlZj0xIG1lX3Jhbmdl"
    "PTE2IGNocm9tYV9tZT0xIHRyZWxsaXM9MSA4eDhkY3Q9MSBjcW09MCBkZWFkem9uZT0yMSwxMSBmYXN0"
    "X3Bza2lwPTEgY2hyb21hX3FwX29mZnNldD0tMiB0aHJlYWRzPTIgbG9va2FoZWFkX3RocmVhZHM9MSBz"
    "bGljZWRfdGhyZWFkcz0wIG5yPTAgZGVjaW1hdGU9MSBpbnRlcmxhY2VkPTAgYmx1cmF5X2NvbXBhdD0w"
    "IGNvbnN0cmFpbmVkX2ludHJhPTAgYmZyYW1lcz0zIGJfcHlyYW1pZD0yIGJfYWRhcHQ9MSBiX2JpYXM9"
    "MCBkaXJlY3Q9MSB3ZWlnaHRiPTEgb3Blbl9nb3A9MCB3ZWlnaHRwPTIga2V5aW50PTI1MCBrZXlpbnRf"
    "bWluPTI1IHNjZW5lY3V0PTQwIGludHJhX3JlZnJlc2g9MCByY19sb29rYWhlYWQ9NDAgcmM9Y3JmIG1i"
    "dHJlZT0xIGNyZj0yMy4wIHFjb21wPTAuNjAgcXBtaW49MCBxcG1heD02OSBxcHN0ZXA9NCBpcF9yYXRp"
    "bz0xLjQwIGFxPTE6MS4wMACAAAAAJ2WIhAA7//7jq/gU2FBUdEzFKP6FtGNPzxSPTYUNLTnUBLOor0B3"
    "gQAAAApBmiRsQ3/+p4+IAAAACEGeQniF/wm5AAAACAGeYXRCvww4AAAACAGeY2pCvww5AAAAEEGaaEmo"
    "QWiZTAhn//6eLfEAAAAKQZ6GRREsL/8JuQAAAAgBnqV0Qr8MOQAAAAgBnqdqQr8MOAAAABBBmqxJqEFs"
    "mUwIV//+OI3AAAAACkGeykUVLC//CbkAAAAIAZ7pdEK/DDgAAAAIAZ7rakK/DDgAAAPVbW9vdgAAAGxt"
    "dmhkAAAAAAAAAAAAAAAAAAAD6AAAAggAAQAAAQAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAA"
    "AAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAwB0cmFrAAAAXHRraGQA"
    "AAADAAAAAAAAAAAAAAABAAAAAAAAAggAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAABAAAA"
    "AAAAAAAAAAAAAABAAAAAAEAAAABAAAAAAAAkZWR0cwAAABxlbHN0AAAAAAAAAAEAAAIIAAAEAAABAAAA"
    "AAJ4bWRpYQAAACBtZGhkAAAAAAAAAAAAAAAAAAAyAAAAGgBVxAAAAAAALWhkbHIAAAAAAAAAAHZpZGUA"
    "AAAAAAAAAAAAAABWaWRlb0hhbmRsZXIAAAACI21pbmYAAAAUdm1oZAAAAAEAAAAAAAAAAAAAACRkaW5m"
    "AAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAAAQAAAeNzdGJsAAAAv3N0c2QAAAAAAAAAAQAAAK9hdmMx"
    "AAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAEAAQABIAAAASAAAAAAAAAABFUxhdmM2Mi4xMS4xMDAgbGli"
    "eDI2NAAAAAAAAAAAAAAAGP//AAAANWF2Y0MBZAAK/+EAGGdkAAqs2UQmwEQAAAMABAAAAwDIPEiWWAEA"
    "Bmjr48siwP34+AAAAAAQcGFzcAAAAAEAAAABAAAAFGJ0cnQAAAAAAAA2BgAAAAAAAAAYc3R0cwAAAAAA"
    "AAABAAAADQAAAgAAAAAUc3RzcwAAAAAAAAABAAAAAQAAAHhjdHRzAAAAAAAAAA0AAAABAAAEAAAAAAEA"
    "AAoAAAAAAQAABAAAAAABAAAAAAAAAAEAAAIAAAAAAQAACgAAAAABAAAEAAAAAAEAAAAAAAAAAQAAAgAA"
    "AAABAAAKAAAAAAEAAAQAAAAAAQAAAAAAAAABAAACAAAAABxzdHNjAAAAAAAAAAEAAAABAAAADQAAAAEA"
    "AABIc3RzegAAAAAAAAAAAAAADQAAAt0AAAAOAAAADAAAAAwAAAAMAAAAFAAAAA4AAAAMAAAADAAAABQA"
    "AAAOAAAADAAAAAwAAAAUc3RjbwAAAAAAAAABAAAAMAAAAGF1ZHRhAAAAWW1ldGEAAAAAAAAAIWhkbHIA"
    "AAAAAAAAAG1kaXJhcHBsAAAAAAAAAAAAAAAALGlsc3QAAAAkqXRvbwAAABxkYXRhAAAAAQAAAABMYXZm"
    "NjIuMy4xMDA="
)
TINY_MP4_BYTES = base64.b64decode(TINY_MP4_BASE64)


def create_test_app() -> FastAPI:
    """Minimal FastAPI test app isolating Cloudinary upload routers."""
    app = FastAPI(title="DoSJE Test App - Task 23 Cloudinary Verification")
    app.include_router(cctv_router)
    app.include_router(inspections_router)
    return app


@pytest.fixture
def client_and_db():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    Base.metadata.create_all(bind=engine)

    app = create_test_app()

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


# ---------------------------------------------------------------------------
# Helper model factories
# ---------------------------------------------------------------------------

def make_project(session: Session, name: str = "Cloudinary Test Project") -> Project:
    project = Project(
        project_name=name,
        project_code=f"CLD-{uuid4().hex[:8].upper()}",
        status="ACTIVE",
        progress=Decimal("15"),
        latitude=Decimal("28.6139"),
        longitude=Decimal("77.2090"),
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def make_camera(session: Session, project_id: int, name: str = "Test Camera") -> Camera:
    camera = Camera(
        project_id=project_id,
        camera_name=name,
        status="ACTIVE",
    )
    session.add(camera)
    session.commit()
    session.refresh(camera)
    return camera


def make_inspection(session: Session, project_id: int) -> Inspection:
    inspection = Inspection(
        project_id=project_id,
        inspection_type="MANUAL",
        status="IN_PROGRESS",
        assignment_status="ASSIGNED",
    )
    session.add(inspection)
    session.commit()
    session.refresh(inspection)
    return inspection


# ---------------------------------------------------------------------------
# Test Cases
# ---------------------------------------------------------------------------

def test_cloudinary_auth_ping():
    """Test 1: Successfully authenticates with Cloudinary via ping."""
    assert is_cloudinary_configured() is True
    get_cloudinary_config()
    res = cloudinary.api.ping()
    assert res.get("status") == "ok"


def test_real_cloudinary_image_evidence_upload(client_and_db):
    """Test 2: Real Cloudinary image upload, DB persistence, and cleanup."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db)
        inspection = make_inspection(db, project.id)
        inspection_id = inspection.id
        project_id = project.id

    uploaded_public_id = None
    try:
        response = client.post(
            f"/inspections/{inspection_id}/evidence",
            files={"file": ("test_evidence.png", TINY_PNG_BYTES, "image/png")},
            data={"description": "Real Cloudinary Verification Photo"},
        )
        assert response.status_code == 201, f"Upload failed: {response.text}"
        data = response.json()

        uploaded_public_id = data["storage_public_id"]

        # 1. Cloudinary upload metadata validation
        assert data["storage_provider"] == "cloudinary"
        assert data["media_type"] == "IMAGE"
        assert data["source_type"] == "MANUAL_UPLOAD"
        assert data["original_filename"] == "test_evidence.png"
        assert data["mime_type"] == "image/png"
        assert data["media_url"].startswith("http")
        assert "res.cloudinary.com" in data["media_url"]
        assert f"dosje/projects/{project_id}/inspections/{inspection_id}/evidence" in uploaded_public_id

        # 2. Database verification
        with session_factory() as db:
            media = db.get(Media, data["id"])
            assert media is not None
            assert media.project_id == project_id
            assert media.inspection_id == inspection_id
            assert media.storage_public_id == uploaded_public_id
            assert media.media_url == data["media_url"]
            assert media.file_size == len(TINY_PNG_BYTES)

        # 3. Verify asset exists on Cloudinary via Admin API
        resource_info = cloudinary.api.resource(uploaded_public_id, resource_type="image")
        assert resource_info["public_id"] == uploaded_public_id
        assert resource_info["resource_type"] == "image"
        assert resource_info["format"] == "png"

    finally:
        # 4. Clean up test asset from Cloudinary
        if uploaded_public_id:
            destroy_res = cloudinary.uploader.destroy(uploaded_public_id, resource_type="image")
            assert destroy_res.get("result") in ["ok", "not found"]


def test_real_cloudinary_video_evidence_upload(client_and_db):
    """Test 3: Real Cloudinary video evidence upload, DB persistence, and cleanup."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db)
        inspection = make_inspection(db, project.id)
        inspection_id = inspection.id
        project_id = project.id

    uploaded_public_id = None
    try:
        response = client.post(
            f"/inspections/{inspection_id}/evidence",
            files={"file": ("evidence_video.mp4", TINY_MP4_BYTES, "video/mp4")},
            data={"description": "Real Cloudinary Verification Video"},
        )
        assert response.status_code == 201, f"Upload failed: {response.text}"
        data = response.json()

        uploaded_public_id = data["storage_public_id"]

        # 1. Metadata checks
        assert data["storage_provider"] == "cloudinary"
        assert data["media_type"] == "VIDEO"
        assert data["original_filename"] == "evidence_video.mp4"
        assert data["media_url"].startswith("http")
        assert "res.cloudinary.com" in data["media_url"]

        # 2. Database verification
        with session_factory() as db:
            media = db.get(Media, data["id"])
            assert media is not None
            assert media.storage_public_id == uploaded_public_id
            assert media.media_type == "VIDEO"

    finally:
        # 3. Cleanup
        if uploaded_public_id:
            destroy_res = cloudinary.uploader.destroy(uploaded_public_id, resource_type="video")
            assert destroy_res.get("result") in ["ok", "not found"]


def test_real_cloudinary_manual_video_upload(client_and_db):
    """Test 4: Real CCTV manual video upload via POST /cctv/{camera_id}/media, DB persistence, and cleanup."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db)
        camera = make_camera(db, project.id)
        camera_id = camera.id
        project_id = project.id

    uploaded_public_id = None
    try:
        response = client.post(
            f"/cctv/{camera_id}/media",
            files={"file": ("cctv_sample.mp4", TINY_MP4_BYTES, "video/mp4")},
        )
        assert response.status_code == 201, f"Upload failed: {response.text}"
        data = response.json()

        uploaded_public_id = data["storage_public_id"]

        # 1. Metadata checks
        assert data["storage_provider"] == "cloudinary"
        assert data["media_type"] == "VIDEO"
        assert data["camera_id"] == camera_id
        assert data["project_id"] == project_id
        assert data["original_filename"] == "cctv_sample.mp4"
        assert data["media_url"].startswith("http")
        assert "res.cloudinary.com" in data["media_url"]
        assert f"dosje/projects/{project_id}/cameras/{camera_id}/manual-videos" in uploaded_public_id

        # 2. Database verification
        with session_factory() as db:
            media = db.get(Media, data["id"])
            assert media is not None
            assert media.camera_id == camera_id
            assert media.storage_public_id == uploaded_public_id

    finally:
        # 3. Cleanup
        if uploaded_public_id:
            destroy_res = cloudinary.uploader.destroy(uploaded_public_id, resource_type="video")
            assert destroy_res.get("result") in ["ok", "not found"]


def test_cloudinary_upload_failure_does_not_persist_db(client_and_db):
    """Test 5: Cloudinary upload failure returns 502 and does not persist any DB records."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db)
        inspection = make_inspection(db, project.id)
        inspection_id = inspection.id

    with patch("cloudinary.uploader.upload", side_effect=Exception("Simulated Cloudinary API Outage")):
        response = client.post(
            f"/inspections/{inspection_id}/evidence",
            files={"file": ("evidence.png", TINY_PNG_BYTES, "image/png")},
        )

    assert response.status_code == 502
    assert response.json()["detail"] == "Failed to upload media to Cloudinary"

    with session_factory() as db:
        assert db.query(Media).count() == 0


def test_db_persistence_failure_rolls_back(client_and_db):
    """Test 6: Database error during media persistence triggers rollback and returns 500."""
    client, session_factory = client_and_db
    with session_factory() as db:
        project = make_project(db)
        inspection = make_inspection(db, project.id)
        inspection_id = inspection.id

    # Mock upload to avoid creating orphan on Cloudinary during simulated DB failure test
    fake_upload_result = {
        "public_id": "test-orphan-mock-id",
        "secure_url": "https://res.cloudinary.com/demo/image/upload/mock.jpg",
        "bytes": 100,
    }
    with patch("cloudinary.uploader.upload", return_value=fake_upload_result):
        with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated DB Write Error")):
            response = client.post(
                f"/inspections/{inspection_id}/evidence",
                files={"file": ("evidence.png", TINY_PNG_BYTES, "image/png")},
            )

    assert response.status_code == 500
    assert response.json()["detail"] == "Failed to save inspection evidence"

    with session_factory() as db:
        assert db.query(Media).count() == 0
