from datetime import datetime
from decimal import Decimal
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.services.location_verification import DEFAULT_LOCATION_VERIFICATION_RADIUS_METERS


class InspectionType(str, Enum):
    RANDOM = "RANDOM"
    ALERT_TRIGGERED = "ALERT_TRIGGERED"
    SCHEDULED = "SCHEDULED"
    MANUAL = "MANUAL"


class InspectionStatus(str, Enum):
    PENDING = "PENDING"
    SCHEDULED = "SCHEDULED"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"


class InspectionAssignmentStatus(str, Enum):
    UNASSIGNED = "UNASSIGNED"
    ASSIGNED = "ASSIGNED"


class InspectionCreate(BaseModel):
    project_id: int = Field(gt=0)
    alert_id: int | None = Field(default=None, gt=0)
    inspection_type: InspectionType
    status: InspectionStatus = InspectionStatus.PENDING
    scheduled_at: datetime | None = None
    started_at: datetime | None = None
    completed_at: datetime | None = None
    officer_name: str | None = Field(default=None, max_length=255)
    officer_id: str | None = Field(default=None, max_length=100)
    assignment_status: InspectionAssignmentStatus | None = InspectionAssignmentStatus.UNASSIGNED
    assigned_at: datetime | None = None
    inspection_latitude: Decimal | None = Field(default=None, ge=Decimal("-90"), le=Decimal("90"))
    inspection_longitude: Decimal | None = Field(default=None, ge=Decimal("-180"), le=Decimal("180"))
    location_accuracy: Decimal | None = Field(default=None, ge=Decimal("0"))
    location_captured_at: datetime | None = None
    location_verified: bool = False
    distance_from_project: Decimal | None = None
    reason: str | None = Field(default=None, max_length=1000)
    findings: str | None = Field(default=None, max_length=2000)
    result: str | None = Field(default=None, max_length=255)
    video_session_id: str | None = Field(default=None, max_length=255)

    def model_dump_clean(self):
        data = self.model_dump(exclude_none=True)
        for key in ["officer_name", "officer_id", "reason", "findings", "result", "video_session_id"]:
            if key in data and isinstance(data[key], str):
                value = data[key].strip()
                if not value:
                    data[key] = None
        return data


class InspectionUpdate(BaseModel):
    project_id: int | None = Field(default=None, gt=0)
    alert_id: int | None = Field(default=None, gt=0)
    inspection_type: InspectionType | None = None
    status: InspectionStatus | None = None
    scheduled_at: datetime | None = None
    started_at: datetime | None = None
    completed_at: datetime | None = None
    officer_name: str | None = Field(default=None, max_length=255)
    officer_id: str | None = Field(default=None, max_length=100)
    assignment_status: InspectionAssignmentStatus | None = InspectionAssignmentStatus.UNASSIGNED
    assigned_at: datetime | None = None
    inspection_latitude: Decimal | None = Field(default=None, ge=Decimal("-90"), le=Decimal("90"))
    inspection_longitude: Decimal | None = Field(default=None, ge=Decimal("-180"), le=Decimal("180"))
    location_accuracy: Decimal | None = Field(default=None, ge=Decimal("0"))
    location_captured_at: datetime | None = None
    location_verified: bool | None = None
    distance_from_project: Decimal | None = None
    reason: str | None = Field(default=None, max_length=1000)
    findings: str | None = Field(default=None, max_length=2000)
    result: str | None = Field(default=None, max_length=255)
    video_session_id: str | None = Field(default=None, max_length=255)


class InspectionStatusUpdate(BaseModel):
    status: InspectionStatus


class InspectionAssignmentCreate(BaseModel):
    inspector_id: str = Field(..., min_length=1, max_length=100)
    inspector_name: str | None = Field(default=None, max_length=255)
    assignment_status: InspectionAssignmentStatus = InspectionAssignmentStatus.ASSIGNED

    @property
    def normalized_inspector_id(self) -> str:
        return self.inspector_id.strip()

    @property
    def normalized_inspector_name(self) -> str | None:
        if self.inspector_name is None:
            return None
        value = self.inspector_name.strip()
        return value or None


class InspectionAssignmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    inspection_id: int
    inspector_id: str | None = None
    inspector_name: str | None = None
    assigned_at: datetime | None = None
    assignment_status: InspectionAssignmentStatus | None = InspectionAssignmentStatus.UNASSIGNED


class InspectionLocationSubmit(BaseModel):
    latitude: Decimal = Field(..., ge=Decimal("-90"), le=Decimal("90"))
    longitude: Decimal = Field(..., ge=Decimal("-180"), le=Decimal("180"))
    location_accuracy: Decimal | None = Field(default=None, ge=Decimal("0"))
    location_captured_at: datetime | None = None


class InspectionLocationResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        json_encoders={Decimal: float},
    )

    inspection_id: int
    project_id: int
    inspection_latitude: Decimal | None = None
    inspection_longitude: Decimal | None = None
    location_accuracy: Decimal | None = None
    location_captured_at: datetime | None = None
    location_verified: bool = False
    distance_from_project: Decimal | None = None
    verification_radius_meters: float = DEFAULT_LOCATION_VERIFICATION_RADIUS_METERS


class InspectionResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        json_encoders={Decimal: float},
    )

    id: int
    project_id: int
    alert_id: int | None = None
    inspection_type: InspectionType
    status: InspectionStatus
    scheduled_at: datetime | None = None
    started_at: datetime | None = None
    completed_at: datetime | None = None
    officer_name: str | None = None
    officer_id: str | None = None
    assignment_status: InspectionAssignmentStatus | None = InspectionAssignmentStatus.UNASSIGNED
    assigned_at: datetime | None = None
    inspection_latitude: Decimal | None = None
    inspection_longitude: Decimal | None = None
    location_accuracy: Decimal | None = None
    location_captured_at: datetime | None = None
    location_verified: bool = False
    distance_from_project: Decimal | None = None
    reason: str | None = None
    findings: str | None = None
    result: str | None = None
    video_session_id: str | None = None
    created_at: datetime
    updated_at: datetime

    @field_validator("location_verified", mode="before")
    @classmethod
    def set_location_verified_default(cls, v: bool | None) -> bool:
        return False if v is None else bool(v)
