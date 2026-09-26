from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class AuditLogCreate(BaseModel):
    project_id: int | None = Field(default=None, gt=0)
    entity_type: str = Field(..., min_length=1, max_length=50)
    entity_id: int | None = Field(default=None, gt=0)
    action: str = Field(..., min_length=1, max_length=50)
    actor_id: str | None = Field(default=None, max_length=100)
    actor_name: str | None = Field(default=None, max_length=255)
    details: str | None = Field(default=None, max_length=2000)

    @field_validator("entity_type", "action")
    @classmethod
    def normalize_required_value(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("value cannot be blank")
        return cleaned

    @field_validator("actor_id", "actor_name", "details")
    @classmethod
    def normalize_optional_value(cls, value: str | None) -> str | None:
        if value is None:
            return value
        cleaned = value.strip()
        return cleaned or None


class AuditLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    project_id: int | None = None
    entity_type: str
    entity_id: int | None = None
    action: str
    actor_id: str | None = None
    actor_name: str | None = None
    details: str | None = None
    created_at: datetime
