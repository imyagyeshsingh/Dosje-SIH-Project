from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class EvidenceType(str, Enum):
    IMAGE = "IMAGE"
    VIDEO = "VIDEO"
    DOCUMENT = "DOCUMENT"
    OTHER = "OTHER"


class ReportEvidenceReferenceCreate(BaseModel):
    external_evidence_id: str = Field(min_length=1, max_length=255)
    evidence_type: EvidenceType
    source: str | None = Field(default=None, max_length=255)


class ReportEvidenceReferenceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    report_id: int
    external_evidence_id: str
    evidence_type: EvidenceType
    source: str | None = None
    created_at: datetime
