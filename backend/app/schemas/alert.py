from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field, field_validator


class AlertType(str, Enum):
    RISK = "RISK"
    AI_ACTIVITY = "AI_ACTIVITY"
    ATTENDANCE = "ATTENDANCE"
    CAMERA = "CAMERA"


class AlertSeverity(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class AlertStatus(str, Enum):
    OPEN = "OPEN"
    ACKNOWLEDGED = "ACKNOWLEDGED"
    RESOLVED = "RESOLVED"


class AlertCreate(BaseModel):
    project_id: int = Field(gt=0)
    alert_type: AlertType
    severity: AlertSeverity
    message: str = Field(min_length=1, max_length=500)
    confidence: float | None = Field(default=None, ge=0.0, le=1.0)
    status: AlertStatus = AlertStatus.OPEN
    source: str | None = Field(default=None, min_length=1, max_length=50)
    detection_id: int | None = Field(default=None, gt=0)

    @field_validator("message")
    @classmethod
    def validate_message(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("message cannot be empty")
        return cleaned

    @field_validator("source")
    @classmethod
    def validate_source(cls, value: str | None) -> str | None:
        if value is None:
            return value
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("source cannot be empty")
        return cleaned


class AlertUpdate(BaseModel):
    status: AlertStatus | None = None


class AlertResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    project_id: int
    alert_type: AlertType
    severity: AlertSeverity
    message: str
    confidence: float | None
    status: AlertStatus
    source: str | None
    detection_id: int | None
    created_at: datetime
    updated_at: datetime
