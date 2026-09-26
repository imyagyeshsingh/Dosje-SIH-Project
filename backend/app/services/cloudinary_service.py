import os
from typing import BinaryIO
from uuid import uuid4

from dotenv import load_dotenv

load_dotenv()

try:
    import cloudinary
    import cloudinary.uploader
except ImportError:  # pragma: no cover - optional until the dependency is installed in the target environment
    cloudinary = None


REQUIRED_ENV_VARS = (
    "CLOUDINARY_CLOUD_NAME",
    "CLOUDINARY_API_KEY",
    "CLOUDINARY_API_SECRET",
)
MAX_VIDEO_FILE_SIZE_BYTES = 100 * 1024 * 1024
MAX_IMAGE_FILE_SIZE_BYTES = 10 * 1024 * 1024
SUPPORTED_IMAGE_MIME_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif",
    "image/bmp",
}
SUPPORTED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}
SUPPORTED_VIDEO_MIME_TYPES = {
    "video/mp4",
    "video/quicktime",
    "video/x-msvideo",
    "video/webm",
    "video/mpeg",
    "video/mp2t",
    "video/3gpp",
    "video/3gpp2",
    "video/ogg",
    "video/x-matroska",
}
SUPPORTED_VIDEO_EXTENSIONS = {
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
}


def is_cloudinary_configured() -> bool:
    return all(bool(os.getenv(name)) for name in REQUIRED_ENV_VARS)


def get_cloudinary_config() -> dict[str, str]:
    values = {name: os.getenv(name) for name in REQUIRED_ENV_VARS}
    missing = [name for name, value in values.items() if not value]
    if missing:
        raise RuntimeError(
            "Cloudinary configuration is missing required environment variables: "
            + ", ".join(missing)
        )

    if cloudinary is not None:
        cloudinary.config(
            cloud_name=values["CLOUDINARY_CLOUD_NAME"],
            api_key=values["CLOUDINARY_API_KEY"],
            api_secret=values["CLOUDINARY_API_SECRET"],
        )
    return values


def validate_media_upload(file_obj: BinaryIO, filename: str, content_type: str | None, file_size: int) -> tuple[str, str]:
    if file_obj is None:
        raise ValueError("Media file is required")
    if not filename or not filename.strip():
        raise ValueError("Media filename is required")
    if file_size <= 0:
        raise ValueError("Media file is empty")

    normalized_mime = (content_type or "").lower()
    extension = os.path.splitext(filename)[1].lower()
    max_size = MAX_VIDEO_FILE_SIZE_BYTES
    media_type = "VIDEO"

    if normalized_mime.startswith("image/") or extension in SUPPORTED_IMAGE_EXTENSIONS:
        max_size = MAX_IMAGE_FILE_SIZE_BYTES
        media_type = "IMAGE"
        if file_size > max_size:
            raise ValueError(
                f"Image file exceeds the supported limit of {MAX_IMAGE_FILE_SIZE_BYTES / (1024 * 1024):.0f}MB"
            )
        return (normalized_mime or "image/jpeg", media_type)

    if normalized_mime.startswith("video/") or extension in SUPPORTED_VIDEO_EXTENSIONS:
        media_type = "VIDEO"
        if file_size > MAX_VIDEO_FILE_SIZE_BYTES:
            raise ValueError(
                f"Video file exceeds the supported limit of {MAX_VIDEO_FILE_SIZE_BYTES / (1024 * 1024):.0f}MB"
            )
        return (normalized_mime or "video/mp4", media_type)

    raise ValueError("Only image and video files are supported")


def validate_video_upload(file_obj: BinaryIO, filename: str, content_type: str | None, file_size: int) -> str:
    mime_type, media_type = validate_media_upload(file_obj, filename, content_type, file_size)
    if media_type != "VIDEO":
        raise ValueError("Only video files are supported for manual upload")
    return mime_type


def upload_media_to_cloudinary(
    file_obj: BinaryIO,
    filename: str,
    project_id: int,
    inspection_id: int,
    content_type: str | None,
    file_size: int,
) -> dict[str, str | int]:
    if not is_cloudinary_configured():
        raise RuntimeError("Cloudinary configuration is missing required environment variables")
    if cloudinary is None:
        raise RuntimeError("Cloudinary SDK is not installed")

    get_cloudinary_config()

    mime_type, media_type = validate_media_upload(file_obj, filename, content_type, file_size)
    resource_type = "image" if media_type == "IMAGE" else "video"
    folder = f"dosje/projects/{project_id}/inspections/{inspection_id}/evidence"
    public_id = f"{project_id}-{inspection_id}-{uuid4().hex}"
    try:
        result = cloudinary.uploader.upload(
            file_obj,
            resource_type=resource_type,
            folder=folder,
            public_id=public_id,
            overwrite=False,
        )
    except Exception as exc:
        raise RuntimeError(f"Cloudinary upload failed: {exc}") from exc

    return {
        "storage_provider": "cloudinary",
        "media_type": media_type,
        "source_type": "MANUAL_UPLOAD",
        "storage_public_id": str(result.get("public_id") or public_id),
        "media_url": str(result.get("secure_url") or result.get("url") or ""),
        "original_filename": filename,
        "mime_type": mime_type,
        "file_size": int(result.get("bytes") or file_size),
    }


def upload_manual_video_to_cloudinary(
    file_obj: BinaryIO,
    filename: str,
    project_id: int,
    camera_id: int,
    content_type: str | None,
    file_size: int,
) -> dict[str, str | int]:
    if not is_cloudinary_configured():
        raise RuntimeError("Cloudinary configuration is missing required environment variables")
    if cloudinary is None:
        raise RuntimeError("Cloudinary SDK is not installed")

    get_cloudinary_config()

    mime_type = validate_video_upload(file_obj, filename, content_type, file_size)
    folder = f"dosje/projects/{project_id}/cameras/{camera_id}/manual-videos"
    public_id = f"{project_id}-{camera_id}-{uuid4().hex}"
    try:
        result = cloudinary.uploader.upload(
            file_obj,
            resource_type="video",
            folder=folder,
            public_id=public_id,
            overwrite=False,
        )
    except Exception as exc:
        raise RuntimeError(f"Cloudinary upload failed: {exc}") from exc

    return {
        "storage_provider": "cloudinary",
        "media_type": "VIDEO",
        "source_type": "MANUAL_UPLOAD",
        "storage_public_id": str(result.get("public_id") or public_id),
        "media_url": str(result.get("secure_url") or result.get("url") or ""),
        "original_filename": filename,
        "mime_type": mime_type,
        "file_size": int(result.get("bytes") or file_size),
    }
