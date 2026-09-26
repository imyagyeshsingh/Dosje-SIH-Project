from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class VideoSessionStatus(str, Enum):
    CREATED = "CREATED"
    ACTIVE = "ACTIVE"
    ENDED = "ENDED"
    CANCELLED = "CANCELLED"


class VideoSessionCreate(BaseModel):
    project_id: int = Field(gt=0)
    inspection_id: int | None = Field(default=None, gt=0)
    officer_name: str | None = Field(default=None, max_length=255)
    representative_name: str | None = Field(default=None, max_length=255)

    def model_dump_clean(self):
        data = self.model_dump(exclude_none=True)
        for key in ["officer_name", "representative_name"]:
            if key in data and isinstance(data[key], str):
                value = data[key].strip()
                if not value:
                    data[key] = None
        return data


class VideoSessionUpdate(BaseModel):
    officer_name: str | None = Field(default=None, max_length=255)
    representative_name: str | None = Field(default=None, max_length=255)


class VideoSessionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    project_id: int
    inspection_id: int | None = None
    session_id: str
    status: VideoSessionStatus
    officer_name: str | None = None
    representative_name: str | None = None
    started_at: datetime | None = None
    ended_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
