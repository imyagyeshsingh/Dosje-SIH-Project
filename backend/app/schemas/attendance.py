from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class AttendanceCreate(BaseModel):
    project_id: int = Field(gt=0)
    expected_workers: int = Field(ge=0)


class AttendanceUpdate(BaseModel):
    expected_workers: int = Field(ge=0)


class AttendanceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    project_id: int
    expected_workers: int
    created_at: datetime
    updated_at: datetime


class AttendanceSummaryResponse(BaseModel):
    project_id: int
    expected_workers: int | None = None
    detected_workers: int | None = None
    attendance_percentage: float | None = None
    detection_timestamp: datetime | None = None
