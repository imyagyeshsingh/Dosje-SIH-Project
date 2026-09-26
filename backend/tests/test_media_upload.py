from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.camera import Camera
from app.models.media import Media
from app.models.project import Project


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


def create_project(session, project_name: str = "Upload Project") -> Project:
    project = Project(
        project_name=project_name,
        project_code=f"MEDIA-UPLOAD-{project_name.lower().replace(' ', '-')}-{datetime.now(timezone.utc).timestamp()}",
        status="ACTIVE",
        progress=50,
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def create_camera(session, project_id: int, camera_name: str = "Upload Cam") -> Camera:
    camera = Camera(
        project_id=project_id,
        camera_name=camera_name,
        stream_url="rtsp://example/live/stream",
        status="ACTIVE",
    )
    session.add(camera)
    session.commit()
    session.refresh(camera)
    return camera


def test_manual_video_upload_succeeds_and_persists_media_metadata(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        upload_payload = {
            "storage_provider": "cloudinary",
            "media_type": "VIDEO",
            "source_type": "MANUAL_UPLOAD",
            "storage_public_id": "dosje/projects/1/cameras/1/manual-videos/demo-video",
            "media_url": "https://res.cloudinary.com/demo/video.mp4",
            "original_filename": "demo-video.mp4",
            "mime_type": "video/mp4",
            "file_size": 12345,
        }

        def fake_upload(file_obj, filename, project_id, camera_id, content_type, file_size):
            return upload_payload

        monkeypatch.setattr("app.routers.cctv.upload_manual_video_to_cloudinary", fake_upload)

        response = client.post(
            f"/cctv/{camera.id}/media",
            files={"file": ("demo-video.mp4", b"video-bytes", "video/mp4")},
        )

        assert response.status_code == 201
        data = response.json()
        assert data["project_id"] == project.id
        assert data["camera_id"] == camera.id
        assert data["media_type"] == "VIDEO"
        assert data["source_type"] == "MANUAL_UPLOAD"
        assert data["storage_provider"] == "cloudinary"
        assert data["media_url"] == "https://res.cloudinary.com/demo/video.mp4"

        saved = db.query(Media).filter(Media.camera_id == camera.id).one()
        assert saved.original_filename == "demo-video.mp4"
        assert saved.mime_type == "video/mp4"
        assert saved.file_size == 12345
    finally:
        db.close()


def test_manual_video_upload_rejects_non_video_file(client_and_db):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        response = client.post(
            f"/cctv/{camera.id}/media",
            files={"file": ("demo.txt", b"not-video", "text/plain")},
        )

        assert response.status_code == 400
        assert "Only video files are supported" in response.json()["detail"]
    finally:
        db.close()


def test_manual_video_upload_requires_valid_camera(client_and_db):
    client, _ = client_and_db
    response = client.post(
        "/cctv/999/media",
        files={"file": ("demo.mp4", b"video-data", "video/mp4")},
    )
    assert response.status_code == 404


def test_manual_video_upload_allows_multiple_video_records_for_same_camera(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        def fake_upload(file_obj, filename, project_id, camera_id, content_type, file_size):
            return {
                "storage_provider": "cloudinary",
                "media_type": "VIDEO",
                "source_type": "MANUAL_UPLOAD",
                "storage_public_id": f"video-{filename}",
                "media_url": f"https://res.cloudinary.com/demo/{filename}",
                "original_filename": filename,
                "mime_type": "video/mp4",
                "file_size": 1000,
            }

        monkeypatch.setattr("app.routers.cctv.upload_manual_video_to_cloudinary", fake_upload)

        first = client.post(
            f"/cctv/{camera.id}/media",
            files={"file": ("first.mp4", b"first-video", "video/mp4")},
        )
        second = client.post(
            f"/cctv/{camera.id}/media",
            files={"file": ("second.mp4", b"second-video", "video/mp4")},
        )

        assert first.status_code == 201
        assert second.status_code == 201
        rows = db.query(Media).filter(Media.camera_id == camera.id).all()
        assert len(rows) == 2
    finally:
        db.close()


def test_get_camera_media_returns_newest_first(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        def fake_upload(file_obj, filename, project_id, camera_id, content_type, file_size):
            return {
                "storage_provider": "cloudinary",
                "media_type": "VIDEO",
                "source_type": "MANUAL_UPLOAD",
                "storage_public_id": f"video-{filename}",
                "media_url": f"https://res.cloudinary.com/demo/{filename}",
                "original_filename": filename,
                "mime_type": "video/mp4",
                "file_size": 1000,
            }

        monkeypatch.setattr("app.routers.cctv.upload_manual_video_to_cloudinary", fake_upload)
        client.post(f"/cctv/{camera.id}/media", files={"file": ("first.mp4", b"a", "video/mp4")})
        client.post(f"/cctv/{camera.id}/media", files={"file": ("second.mp4", b"b", "video/mp4")})

        response = client.get(f"/cctv/{camera.id}/media")
        assert response.status_code == 200
        data = response.json()
        assert [item["original_filename"] for item in data] == ["second.mp4", "first.mp4"]
    finally:
        db.close()


def test_camera_media_is_project_isolated(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project_a = create_project(db, "Project A")
        project_b = create_project(db, "Project B")
        camera_a = create_camera(db, project_a.id, "Camera A")
        camera_b = create_camera(db, project_b.id, "Camera B")

        def fake_upload(file_obj, filename, project_id, camera_id, content_type, file_size):
            return {
                "storage_provider": "cloudinary",
                "media_type": "VIDEO",
                "source_type": "MANUAL_UPLOAD",
                "storage_public_id": f"video-{filename}",
                "media_url": f"https://res.cloudinary.com/demo/{filename}",
                "original_filename": filename,
                "mime_type": "video/mp4",
                "file_size": 1000,
            }

        monkeypatch.setattr("app.routers.cctv.upload_manual_video_to_cloudinary", fake_upload)
        client.post(f"/cctv/{camera_a.id}/media", files={"file": ("a.mp4", b"a", "video/mp4")})
        client.post(f"/cctv/{camera_b.id}/media", files={"file": ("b.mp4", b"b", "video/mp4")})

        response_a = client.get(f"/cctv/{camera_a.id}/media")
        response_b = client.get(f"/cctv/{camera_b.id}/media")

        assert response_a.status_code == 200
        assert response_b.status_code == 200
        assert [item["original_filename"] for item in response_a.json()] == ["a.mp4"]
        assert [item["original_filename"] for item in response_b.json()] == ["b.mp4"]
    finally:
        db.close()


def test_manual_video_upload_handles_cloudinary_failure(client_and_db, monkeypatch):
    client, SessionLocal = client_and_db
    db = SessionLocal()
    try:
        project = create_project(db)
        camera = create_camera(db, project.id)

        def fake_upload(file_obj, filename, project_id, camera_id, content_type, file_size):
            raise RuntimeError("Cloudinary unavailable")

        monkeypatch.setattr("app.routers.cctv.upload_manual_video_to_cloudinary", fake_upload)

        response = client.post(
            f"/cctv/{camera.id}/media",
            files={"file": ("demo.mp4", b"video-data", "video/mp4")},
        )

        assert response.status_code == 502
        assert response.json()["detail"] == "Failed to upload video to Cloudinary"
        assert db.query(Media).count() == 0
    finally:
        db.close()
