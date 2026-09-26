from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class CameraStatus(str, Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    OFFLINE = "OFFLINE"


VALID_URL_SCHEMES = (
    "http://",
    "https://",
    "rtsp://",
    "rtmp://",
    "rtspt://",
    "udp://",
    "tcp://",
)


class CameraCreate(BaseModel):
    project_id: int = Field(gt=0)
    camera_name: str = Field(min_length=1, max_length=255)
    stream_url: str | None = Field(default=None, min_length=1, max_length=2048)
    video_path: str | None = Field(default=None, min_length=1, max_length=1024)
    status: CameraStatus = CameraStatus.ACTIVE
    last_active: datetime | None = None

    @field_validator("camera_name")
    @classmethod
    def validate_camera_name(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("camera_name cannot be empty")
        return cleaned

    @field_validator("stream_url")
    @classmethod
    def validate_stream_url(cls, value: str | None) -> str | None:
        if value is None:
            return value
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("stream_url cannot be empty")
        if " " in cleaned or "\n" in cleaned or "\r" in cleaned:
            raise ValueError("stream_url contains invalid characters")
        if not cleaned.lower().startswith(VALID_URL_SCHEMES):
            raise ValueError("stream_url must start with a valid scheme (http, https, rtsp, etc.)")
        return cleaned

    @field_validator("video_path")
    @classmethod
    def validate_video_path(cls, value: str | None) -> str | None:
        if value is None:
            return value
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("video_path cannot be empty")
        if " " in cleaned or "\n" in cleaned or "\r" in cleaned:
            raise ValueError("video_path contains invalid characters")
        return cleaned

    @model_validator(mode="after")
    def validate_video_source(self) -> "CameraCreate":
        if not any(source and source.strip() for source in (self.stream_url, self.video_path)):
            raise ValueError("Either stream_url or video_path must be provided")
        return self


class CameraUpdate(BaseModel):
    camera_name: str | None = Field(default=None, min_length=1, max_length=255)
    stream_url: str | None = Field(default=None, min_length=1, max_length=2048)
    video_path: str | None = Field(default=None, min_length=1, max_length=1024)
    status: CameraStatus | None = None
    last_active: datetime | None = None

    @field_validator("camera_name")
    @classmethod
    def validate_camera_name_optional(cls, value: str | None) -> str | None:
        if value is None:
            return value
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("camera_name cannot be empty")
        return cleaned

    @field_validator("stream_url")
    @classmethod
    def validate_stream_url_optional(cls, value: str | None) -> str | None:
        if value is None:
            return value
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("stream_url cannot be empty")
        if " " in cleaned or "\n" in cleaned or "\r" in cleaned:
            raise ValueError("stream_url contains invalid characters")
        if not cleaned.lower().startswith(VALID_URL_SCHEMES):
            raise ValueError("stream_url must start with a valid scheme (http, https, rtsp, etc.)")
        return cleaned

    @field_validator("video_path")
    @classmethod
    def validate_video_path_optional(cls, value: str | None) -> str | None:
        if value is None:
            return value
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("video_path cannot be empty")
        if " " in cleaned or "\n" in cleaned or "\r" in cleaned:
            raise ValueError("video_path contains invalid characters")
        return cleaned


class CameraStatusUpdate(BaseModel):
    status: CameraStatus


class CameraResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    project_id: int
    camera_name: str
    stream_url: str | None
    video_path: str | None
    status: CameraStatus
    last_active: datetime | None
    created_at: datetime
    updated_at: datetime
