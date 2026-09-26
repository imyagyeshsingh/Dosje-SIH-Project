from datetime import date, datetime
from decimal import Decimal
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class ProjectStatus(str, Enum):
    PLANNED = "PLANNED"
    ACTIVE = "ACTIVE"
    DELAYED = "DELAYED"
    COMPLETED = "COMPLETED"
    AT_RISK = "AT_RISK"


class ProjectCreate(BaseModel):
    project_name: str = Field(min_length=1, max_length=255)
    project_code: str = Field(min_length=1, max_length=100)
    description: str | None = None
    location: str | None = Field(default=None, max_length=255)
    latitude: Decimal | None = Field(default=None, ge=Decimal("-90"), le=Decimal("90"))
    longitude: Decimal | None = Field(default=None, ge=Decimal("-180"), le=Decimal("180"))
    department: str | None = Field(default=None, max_length=255)
    status: ProjectStatus = ProjectStatus.PLANNED
    start_date: date | None = None
    expected_end_date: date | None = None
    progress: Decimal = Field(default=Decimal("0"), ge=Decimal("0"), le=Decimal("100"))

    @field_validator("project_name")
    @classmethod
    def validate_project_name(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("project_name cannot be empty")
        return cleaned

    @field_validator("project_code")
    @classmethod
    def validate_project_code(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("project_code cannot be empty")
        return cleaned

    @model_validator(mode="after")
    def validate_dates(self) -> "ProjectCreate":
        if (
            self.start_date is not None
            and self.expected_end_date is not None
            and self.expected_end_date < self.start_date
        ):
            raise ValueError("expected_end_date must be on or after start_date")
        return self


class ProjectUpdate(BaseModel):
    project_name: str | None = Field(default=None, min_length=1, max_length=255)
    project_code: str | None = Field(default=None, min_length=1, max_length=100)
    description: str | None = None
    location: str | None = Field(default=None, max_length=255)
    latitude: Decimal | None = Field(default=None, ge=Decimal("-90"), le=Decimal("90"))
    longitude: Decimal | None = Field(default=None, ge=Decimal("-180"), le=Decimal("180"))
    department: str | None = Field(default=None, max_length=255)
    status: ProjectStatus | None = None
    start_date: date | None = None
    expected_end_date: date | None = None
    progress: Decimal | None = Field(default=None, ge=Decimal("0"), le=Decimal("100"))

    @field_validator("project_name")
    @classmethod
    def validate_project_name_optional(cls, value: str | None) -> str | None:
        if value is None:
            return value
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("project_name cannot be empty")
        return cleaned

    @field_validator("project_code")
    @classmethod
    def validate_project_code_optional(cls, value: str | None) -> str | None:
        if value is None:
            return value
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("project_code cannot be empty")
        return cleaned

    @model_validator(mode="after")
    def validate_dates(self) -> "ProjectUpdate":
        if (
            self.start_date is not None
            and self.expected_end_date is not None
            and self.expected_end_date < self.start_date
        ):
            raise ValueError("expected_end_date must be on or after start_date")
        return self


class ProjectResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    project_name: str
    project_code: str
    description: str | None
    location: str | None
    latitude: Decimal | None
    longitude: Decimal | None
    department: str | None
    status: ProjectStatus
    start_date: date | None
    expected_end_date: date | None
    progress: Decimal
    created_at: datetime
    updated_at: datetime


class ProjectSummaryProject(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    project_name: str
    project_code: str
    description: str | None
    location: str | None
    latitude: Decimal | None
    longitude: Decimal | None
    department: str | None
    status: ProjectStatus
    start_date: date | None
    expected_end_date: date | None
    progress: Decimal


class RiskSummary(BaseModel):
    score: int | None = None
    level: str | None = None


class AttendanceSummary(BaseModel):
    expected_workers: int | None = None
    detected_workers: int | None = None
    percentage: Decimal | None = None


class AlertsSummary(BaseModel):
    total: int = 0
    active: int = 0


class InspectionsSummary(BaseModel):
    total: int = 0
    pending: int = 0
    completed: int = 0


class CctvSummary(BaseModel):
    total_cameras: int = 0
    active_cameras: int = 0


class ProjectSummaryResponse(BaseModel):
    project: ProjectSummaryProject
    risk: RiskSummary = Field(default_factory=RiskSummary)
    attendance: AttendanceSummary = Field(default_factory=AttendanceSummary)
    alerts: AlertsSummary = Field(default_factory=AlertsSummary)
    inspections: InspectionsSummary = Field(default_factory=InspectionsSummary)
    cctv: CctvSummary = Field(default_factory=CctvSummary)
