from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ReportType(str, Enum):
    INSPECTION = "INSPECTION"
    MONITORING = "MONITORING"
    INCIDENT = "INCIDENT"


class ReportStatus(str, Enum):
    DRAFT = "DRAFT"
    FINAL = "FINAL"


class ReportCreate(BaseModel):
    project_id: int = Field(gt=0)
    inspection_id: int = Field(gt=0)
    report_type: ReportType
    status: ReportStatus = ReportStatus.DRAFT
    title: str = Field(min_length=1, max_length=255)
    summary: str | None = Field(default=None, max_length=2000)
    findings: str | None = Field(default=None, max_length=5000)
    recommendations: str | None = Field(default=None, max_length=5000)
    generated_at: datetime | None = None

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("title cannot be empty")
        return cleaned


class ReportUpdate(BaseModel):
    project_id: int | None = Field(default=None, gt=0)
    inspection_id: int | None = Field(default=None, gt=0)
    report_type: ReportType | None = None
    status: ReportStatus | None = None
    title: str | None = Field(default=None, min_length=1, max_length=255)
    summary: str | None = Field(default=None, max_length=2000)
    findings: str | None = Field(default=None, max_length=5000)
    recommendations: str | None = Field(default=None, max_length=5000)
    generated_at: datetime | None = None

    @field_validator("title")
    @classmethod
    def validate_title_optional(cls, value: str | None) -> str | None:
        if value is None:
            return value
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("title cannot be empty")
        return cleaned


class ReportResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    project_id: int
    inspection_id: int
    report_type: ReportType
    status: ReportStatus
    title: str
    summary: str | None = None
    findings: str | None = None
    recommendations: str | None = None
    generated_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
