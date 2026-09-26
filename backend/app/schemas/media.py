from datetime import datetime
from decimal import Decimal
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field, field_validator


class MediaType(str, Enum):
    IMAGE = "IMAGE"
    VIDEO = "VIDEO"
    DOCUMENT = "DOCUMENT"


class MediaSourceType(str, Enum):
    UPLOAD = "UPLOAD"
    MANUAL = "MANUAL"
    MANUAL_UPLOAD = "MANUAL_UPLOAD"
    AI_GENERATED = "AI_GENERATED"


class MediaCreate(BaseModel):
    project_id: int = Field(gt=0)
    inspection_id: int | None = Field(default=None, gt=0)
    camera_id: int | None = Field(default=None, gt=0)
    media_type: MediaType
    source_type: MediaSourceType
    storage_provider: str = Field(default="cloudinary", min_length=1, max_length=50)
    storage_public_id: str = Field(min_length=1, max_length=512)
    media_url: str = Field(min_length=1, max_length=2048)
    original_filename: str | None = Field(default=None, min_length=1, max_length=255)
    mime_type: str | None = Field(default=None, min_length=1, max_length=100)
    file_size: int | None = Field(default=None, ge=0)
    description: str | None = Field(default=None, max_length=2000)
    captured_at: datetime | None = None
    latitude: Decimal | None = Field(default=None, ge=Decimal("-90"), le=Decimal("90"))
    longitude: Decimal | None = Field(default=None, ge=Decimal("-180"), le=Decimal("180"))
    location_accuracy: Decimal | None = Field(default=None, ge=Decimal("0"))

    @field_validator("media_url")
    @classmethod
    def validate_media_url(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("media_url cannot be empty")
        if " " in cleaned or "\n" in cleaned or "\r" in cleaned:
            raise ValueError("media_url contains invalid characters")
        if not cleaned.lower().startswith(("http://", "https://")):
            raise ValueError("media_url must be a valid http or https URL")
        return cleaned


class MediaResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        json_encoders={Decimal: float},
    )

    id: int
    project_id: int
    inspection_id: int | None = None
    camera_id: int | None = None
    media_type: MediaType
    source_type: MediaSourceType
    storage_provider: str
    storage_public_id: str
    media_url: str
    original_filename: str | None = None
    mime_type: str | None = None
    file_size: int | None = None
    description: str | None = None
    captured_at: datetime | None = None
    latitude: Decimal | None = None
    longitude: Decimal | None = None
    location_accuracy: Decimal | None = None
    created_at: datetime
