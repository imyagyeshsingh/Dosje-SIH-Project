from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class InspectorCreate(BaseModel):
    inspector_id: str = Field(..., min_length=1, max_length=100)
    inspector_name: str = Field(..., min_length=1, max_length=255)
    is_active: bool = True

    @property
    def normalized_inspector_id(self) -> str:
        return self.inspector_id.strip()

    @property
    def normalized_inspector_name(self) -> str:
        return self.inspector_name.strip()


class InspectorResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    inspector_id: str
    inspector_name: str
    is_active: bool = True
    created_at: datetime
    updated_at: datetime
