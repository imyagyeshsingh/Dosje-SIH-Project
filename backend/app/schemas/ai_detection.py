from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


CANONICAL_ACTIVITIES: tuple[str, ...] = (
    "NORMAL",
    "LOW",
    "NO_ACTIVITY",
    "HIGH",
    "SUSPICIOUS",
)

ACTIVITY_ALIASES: dict[str, str] = {
    # NORMAL
    "NORMAL": "NORMAL",
    "WORKERS PRESENT": "NORMAL",
    "CONSTRUCTION ACTIVITY DETECTED": "NORMAL",
    "NORMAL ACTIVITY": "NORMAL",
    "NORMAL_ACTIVITY": "NORMAL",
    # LOW
    "LOW": "LOW",
    "LOW ACTIVITY": "LOW",
    "LOW_ACTIVITY": "LOW",
    # NO_ACTIVITY
    "NO_ACTIVITY": "NO_ACTIVITY",
    "NO ACTIVITY": "NO_ACTIVITY",
    "NONE": "NO_ACTIVITY",
    "INACTIVE": "NO_ACTIVITY",
    # HIGH
    "HIGH": "HIGH",
    "HIGH ACTIVITY": "HIGH",
    "HIGH_ACTIVITY": "HIGH",
    # SUSPICIOUS
    "SUSPICIOUS": "SUSPICIOUS",
    "SUSPICIOUS ACTIVITY": "SUSPICIOUS",
    "SUSPICIOUS_ACTIVITY": "SUSPICIOUS",
}


def normalize_activity(value: str) -> str:
    cleaned = value.strip()
    if not cleaned:
        raise ValueError("activity must be a non-empty string")

    normalized_key = " ".join(cleaned.upper().split())
    if normalized_key in ACTIVITY_ALIASES:
        return ACTIVITY_ALIASES[normalized_key]

    underscore_key = normalized_key.replace("-", "_")
    if underscore_key in ACTIVITY_ALIASES:
        return ACTIVITY_ALIASES[underscore_key]

    supported = ", ".join(CANONICAL_ACTIVITIES)
    raise ValueError(f"Invalid activity '{value}'. Supported canonical values: {supported}")


class AIDetectionCreate(BaseModel):
    project_id: int = Field(gt=0)
    camera_id: int = Field(gt=0)
    people_detected: int = Field(ge=0)
    activity: str = Field(min_length=1, max_length=50)
    confidence: float = Field(ge=0.0, le=1.0)
    timestamp: datetime

    @field_validator("activity")
    @classmethod
    def validate_activity(cls, value: str) -> str:
        return normalize_activity(value)


class AIDetectionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    project_id: int
    camera_id: int
    people_detected: int
    activity: str
    confidence: float
    timestamp: datetime
    created_at: datetime


class AIDetectionSummaryResponse(BaseModel):
    project_id: int
    latest_people_detected: int | None = None
    latest_activity: str | None = None
    latest_confidence: float | None = None
    latest_timestamp: datetime | None = None
    detection_count: int = 0
