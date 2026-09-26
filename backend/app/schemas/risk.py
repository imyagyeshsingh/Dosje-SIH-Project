from enum import Enum

from pydantic import BaseModel, Field


class RiskLevel(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class RiskResponse(BaseModel):
    score: int | None = Field(default=None, ge=0, le=100)
    level: RiskLevel | None = None
