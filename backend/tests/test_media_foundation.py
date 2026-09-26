from datetime import datetime, timezone

import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base
from app.models.ai_detection import AIDetection
from app.models.alert import Alert
from app.models.camera import Camera
from app.models.inspection import Inspection
from app.models.media import Media
from app.models.project import Project
from app.schemas.media import MediaCreate, MediaResponse, MediaSourceType, MediaType
from app.services.cloudinary_service import get_cloudinary_config


@pytest.fixture
def media_session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    Base.metadata.create_all(bind=engine)

    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


def create_project(session, project_name: str = "Media Project") -> Project:
    project = Project(
        project_name=project_name,
        project_code=f"MEDIA-{project_name.lower().replace(' ', '-')}-{datetime.now(timezone.utc).timestamp()}",
        status="ACTIVE",
        progress=50,
    )
    session.add(project)
    session.commit()
    session.refresh(project)
    return project


def create_camera(session, project_id: int, camera_name: str = "Front Camera") -> Camera:
    camera = Camera(
        project_id=project_id,
        camera_name=camera_name,
        stream_url="rtsp://example/camera/stream",
        status="ACTIVE",
    )
    session.add(camera)
    session.commit()
    session.refresh(camera)
    return camera


def test_media_model_can_be_imported():
    assert Media.__tablename__ == "media"
    assert "media" in Base.metadata.tables


def test_media_schema_accepts_valid_payload():
    payload = MediaCreate(
        project_id=1,
        camera_id=2,
        media_type="VIDEO",
        source_type="UPLOAD",
        storage_provider="cloudinary",
        storage_public_id="projects/demo/video-001",
        media_url="https://res.cloudinary.com/demo/video-001.mp4",
        original_filename="video-001.mp4",
        mime_type="video/mp4",
        file_size=1024,
    )

    assert payload.project_id == 1
    assert payload.camera_id == 2
    assert payload.media_type == MediaType.VIDEO
    assert payload.source_type == MediaSourceType.UPLOAD
    assert payload.storage_provider == "cloudinary"


def test_media_schema_rejects_invalid_project_id():
    with pytest.raises(ValidationError):
        MediaCreate(
            project_id=0,
            camera_id=1,
            media_type="IMAGE",
            source_type="UPLOAD",
            storage_provider="cloudinary",
            storage_public_id="projects/demo/image-001",
            media_url="https://res.cloudinary.com/demo/image-001.jpg",
            original_filename="image-001.jpg",
            mime_type="image/jpeg",
            file_size=2048,
        )


def test_media_schema_rejects_invalid_camera_id():
    with pytest.raises(ValidationError):
        MediaCreate(
            project_id=1,
            camera_id=0,
            media_type="IMAGE",
            source_type="UPLOAD",
            storage_provider="cloudinary",
            storage_public_id="projects/demo/image-002",
            media_url="https://res.cloudinary.com/demo/image-002.jpg",
            original_filename="image-002.jpg",
            mime_type="image/jpeg",
            file_size=2048,
        )


def test_media_allows_project_reference_and_optional_camera_reference(media_session):
    project = create_project(media_session)
    camera = create_camera(media_session, project.id)

    media = Media(
        project_id=project.id,
        camera_id=camera.id,
        media_type="VIDEO",
        source_type="UPLOAD",
        storage_provider="cloudinary",
        storage_public_id="projects/demo/camera-video",
        media_url="https://example.com/media/camera-video.mp4",
        original_filename="camera-video.mp4",
        mime_type="video/mp4",
        file_size=2048,
    )
    media_session.add(media)
    media_session.commit()
    media_session.refresh(media)

    media_without_camera = Media(
        project_id=project.id,
        media_type="IMAGE",
        source_type="MANUAL",
        storage_provider="cloudinary",
        storage_public_id="projects/demo/manual-image",
        media_url="https://example.com/media/manual-image.jpg",
        original_filename="manual-image.jpg",
        mime_type="image/jpeg",
        file_size=1024,
    )
    media_session.add(media_without_camera)
    media_session.commit()
    media_session.refresh(media_without_camera)

    assert media.project_id == project.id
    assert media.camera_id == camera.id
    assert media_without_camera.camera_id is None


def test_multiple_media_records_can_share_one_camera(media_session):
    project = create_project(media_session)
    camera = create_camera(media_session, project.id)

    media_a = Media(
        project_id=project.id,
        camera_id=camera.id,
        media_type="VIDEO",
        source_type="UPLOAD",
        storage_provider="cloudinary",
        storage_public_id="projects/demo/video-a",
        media_url="https://example.com/media/video-a.mp4",
        original_filename="video-a.mp4",
        mime_type="video/mp4",
        file_size=1000,
    )
    media_b = Media(
        project_id=project.id,
        camera_id=camera.id,
        media_type="IMAGE",
        source_type="UPLOAD",
        storage_provider="cloudinary",
        storage_public_id="projects/demo/video-b",
        media_url="https://example.com/media/video-b.jpg",
        original_filename="video-b.jpg",
        mime_type="image/jpeg",
        file_size=2000,
    )

    media_session.add_all([media_a, media_b])
    media_session.commit()

    rows = media_session.query(Media).filter(Media.camera_id == camera.id).all()

    assert len(rows) == 2
    assert {row.storage_public_id for row in rows} == {"projects/demo/video-a", "projects/demo/video-b"}


def test_media_response_serializes_sqlalchemy_model():
    media = Media(
        id=7,
        project_id=3,
        camera_id=4,
        media_type="VIDEO",
        source_type="UPLOAD",
        storage_provider="cloudinary",
        storage_public_id="projects/demo/final-recording",
        media_url="https://example.com/media/final-recording.mp4",
        original_filename="final-recording.mp4",
        mime_type="video/mp4",
        file_size=4096,
        created_at=datetime(2026, 9, 21, 8, 15, tzinfo=timezone.utc),
    )

    response = MediaResponse.model_validate(media)

    assert response.id == 7
    assert response.project_id == 3
    assert response.camera_id == 4
    assert response.media_type == MediaType.VIDEO
    assert response.source_type == MediaSourceType.UPLOAD
    assert response.media_url == "https://example.com/media/final-recording.mp4"


def test_missing_cloudinary_configuration_raises_runtime_error(monkeypatch):
    for key in [
        "CLOUDINARY_CLOUD_NAME",
        "CLOUDINARY_API_KEY",
        "CLOUDINARY_API_SECRET",
    ]:
        monkeypatch.delenv(key, raising=False)

    with pytest.raises(RuntimeError, match="CLOUDINARY"):
        get_cloudinary_config()


# --- Task 21A: media_url validation ---

def test_media_schema_rejects_blank_media_url():
    with pytest.raises(ValidationError):
        MediaCreate(
            project_id=1,
            media_type="IMAGE",
            source_type="UPLOAD",
            storage_provider="cloudinary",
            storage_public_id="projects/demo/blank",
            media_url="   ",
        )


def test_media_schema_rejects_non_url_media_url():
    with pytest.raises(ValidationError):
        MediaCreate(
            project_id=1,
            media_type="IMAGE",
            source_type="UPLOAD",
            storage_provider="cloudinary",
            storage_public_id="projects/demo/bad",
            media_url="not-a-url",
        )


def test_media_schema_rejects_media_url_with_spaces():
    with pytest.raises(ValidationError):
        MediaCreate(
            project_id=1,
            media_type="IMAGE",
            source_type="UPLOAD",
            storage_provider="cloudinary",
            storage_public_id="projects/demo/spaces",
            media_url="https://example com/media/file.jpg",
        )
