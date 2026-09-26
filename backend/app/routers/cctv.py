from datetime import datetime, timezone
from pathlib import PurePosixPath

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.camera import Camera
from app.models.media import Media
from app.models.project import Project
from app.schemas.camera import CameraCreate, CameraResponse, CameraStatusUpdate
from app.schemas.media import MediaResponse
from app.services.cloudinary_service import MAX_VIDEO_FILE_SIZE_BYTES, upload_manual_video_to_cloudinary


router = APIRouter(prefix="/cctv", tags=["CCTV"])


def get_camera_or_404(camera_id: int, db: Session) -> Camera:
    camera = db.get(Camera, camera_id)
    if camera is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Camera not found")
    return camera


@router.post("", response_model=CameraResponse, status_code=status.HTTP_201_CREATED)
def create_camera(camera_data: CameraCreate, db: Session = Depends(get_db)) -> Camera:
    if db.get(Project, camera_data.project_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    camera = Camera(**camera_data.model_dump())
    db.add(camera)
    try:
        db.commit()
        db.refresh(camera)
        return camera
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create camera",
        )


@router.get("/project/{project_id}", response_model=list[CameraResponse])
def list_project_cameras(
    project_id: int,
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[Camera]:
    if db.get(Project, project_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    statement = (
        select(Camera)
        .where(Camera.project_id == project_id)
        .order_by(Camera.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    return list(db.scalars(statement).all())


@router.get("/{camera_id}", response_model=CameraResponse)
def get_camera(camera_id: int, db: Session = Depends(get_db)) -> Camera:
    return get_camera_or_404(camera_id, db)


@router.put("/{camera_id}/status", response_model=CameraResponse)
def update_camera_status(
    camera_id: int, status_data: CameraStatusUpdate, db: Session = Depends(get_db)
) -> Camera:
    camera = get_camera_or_404(camera_id, db)
    camera.status = status_data.status
    if status_data.status == "ACTIVE":
        camera.last_active = datetime.now(timezone.utc)

    try:
        db.commit()
        db.refresh(camera)
        return camera
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update camera status",
        )


@router.post("/{camera_id}/media", response_model=MediaResponse, status_code=status.HTTP_201_CREATED)
def upload_camera_media(
    camera_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
) -> Media:
    camera = get_camera_or_404(camera_id, db)
    if db.get(Project, camera.project_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    if file is None or file.filename is None or not file.filename.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Video file is required")

    try:
        file.file.seek(0, 2)
        file_size = file.file.tell()
        file.file.seek(0)
    except (AttributeError, OSError):
        file_size = 0

    if file_size <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Video file is empty")
    if file_size > MAX_VIDEO_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=(
                f"Video file exceeds the supported limit of {MAX_VIDEO_FILE_SIZE_BYTES / (1024 * 1024):.0f}MB"
            ),
        )

    mime_type = (file.content_type or "").lower()
    extension = PurePosixPath(file.filename).suffix.lower()
    if not mime_type.startswith("video/") and extension not in {
        ".mp4",
        ".mov",
        ".avi",
        ".webm",
        ".mpeg",
        ".mpg",
        ".m4v",
        ".3gp",
        ".3g2",
        ".ogv",
        ".mkv",
    }:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Only video files are supported")

    try:
        upload_result = upload_manual_video_to_cloudinary(
            file_obj=file.file,
            filename=file.filename,
            project_id=camera.project_id,
            camera_id=camera.id,
            content_type=file.content_type,
            file_size=file_size,
        )
    except (RuntimeError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to upload video to Cloudinary",
        ) from None

    try:
        media = Media(
            project_id=camera.project_id,
            camera_id=camera.id,
            media_type=upload_result["media_type"],
            source_type=upload_result["source_type"],
            storage_provider=upload_result["storage_provider"],
            storage_public_id=upload_result["storage_public_id"],
            media_url=upload_result["media_url"],
            original_filename=upload_result["original_filename"],
            mime_type=upload_result["mime_type"],
            file_size=int(upload_result["file_size"]),
        )
        db.add(media)
        db.commit()
        db.refresh(media)
        return media
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save uploaded media metadata",
        )


@router.get("/{camera_id}/media", response_model=list[MediaResponse])
def list_camera_media(
    camera_id: int,
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[Media]:
    get_camera_or_404(camera_id, db)
    statement = (
        select(Media)
        .where(Media.camera_id == camera_id)
        .order_by(Media.created_at.desc(), Media.id.desc())
        .limit(limit)
        .offset(offset)
    )
    return list(db.scalars(statement).all())
