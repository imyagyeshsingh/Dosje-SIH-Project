from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field, field_validator


class NotificationType(str, Enum):
    ALERT = "ALERT"
    INSPECTION = "INSPECTION"
    ASSIGNMENT = "ASSIGNMENT"
    REPORT = "REPORT"
    VIDEO_SESSION = "VIDEO_SESSION"
    SYSTEM = "SYSTEM"


class NotificationSeverity(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class NotificationCreate(BaseModel):
    project_id: int = Field(gt=0)
    notification_type: NotificationType
    message: str = Field(min_length=1, max_length=500)
    source: str = Field(min_length=1, max_length=50)
    severity: NotificationSeverity | None = None
    title: str | None = Field(default=None, max_length=255)
    recipient_id: str | None = Field(default=None, max_length=100)
    recipient_role: str | None = Field(default=None, max_length=50)
    alert_id: int | None = Field(default=None, gt=0)
    inspection_id: int | None = Field(default=None, gt=0)

    @field_validator("message")
    @classmethod
    def validate_message(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("message cannot be empty")
        return cleaned

    @field_validator("source")
    @classmethod
    def validate_source(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("source cannot be empty")
        return cleaned

    @field_validator("title", "recipient_id", "recipient_role")
    @classmethod
    def normalize_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return value
        cleaned = value.strip()
        return cleaned or None


class NotificationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    project_id: int
    recipient_id: str | None
    recipient_role: str | None
    notification_type: NotificationType
    severity: NotificationSeverity | None
    title: str | None
    message: str
    source: str
    alert_id: int | None
    inspection_id: int | None
    is_read: bool
    read_at: datetime | None
    created_at: datetime
    updated_at: datetime


class NotificationSummaryResponse(BaseModel):
    total: int = 0
    unread: int = 0


class NotificationBulkReadResponse(BaseModel):
    marked_read: int = 0
