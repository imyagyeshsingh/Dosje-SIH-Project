from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.risk import RiskLevel


class ReportAggregationRisk(BaseModel):
    score: int | None = Field(default=None, ge=0, le=100)
    level: RiskLevel | None = None


class ReportAggregationAttendance(BaseModel):
    expected_workers: int | None = None
    detected_workers: int | None = None
    attendance_percentage: float | None = None
    detection_timestamp: datetime | None = None


class ReportAggregationCCTV(BaseModel):
    total_cameras: int = 0
    active_cameras: int = 0


class ReportAggregationAI(BaseModel):
    total_detections: int = 0
    latest_detection_id: int | None = None
    latest_activity: str | None = None
    latest_people_detected: int | None = None
    latest_confidence: float | None = None
    latest_timestamp: datetime | None = None


class ReportAggregationAlerts(BaseModel):
    total_alerts: int = 0
    active_alerts: int = 0
    resolved_alerts: int = 0


class ReportAggregationInspections(BaseModel):
    total_inspections: int = 0
    pending: int = 0
    scheduled: int = 0
    in_progress: int = 0
    completed: int = 0
    cancelled: int = 0
    latest_inspection_id: int | None = None
    latest_inspection_status: str | None = None


class ReportAggregationVideoSessions(BaseModel):
    total_sessions: int = 0
    active_sessions: int = 0
    ended_sessions: int = 0
    latest_session_id: int | None = None
    latest_session_status: str | None = None


class ReportAggregationEvidence(BaseModel):
    total_references: int = 0
    project_evidence_ids: list[str] = Field(default_factory=list)


class ReportInspectionContext(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int | None = None
    inspection_type: str | None = None
    status: str | None = None
    officer_name: str | None = None
    reason: str | None = None


class ReportAggregationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    report_id: int
    project_id: int
    project_name: str
    project_code: str
    risk: ReportAggregationRisk
    attendance: ReportAggregationAttendance
    cctv: ReportAggregationCCTV
    ai: ReportAggregationAI
    alerts: ReportAggregationAlerts
    inspections: ReportAggregationInspections
    video_sessions: ReportAggregationVideoSessions
    evidence: ReportAggregationEvidence
    inspection: ReportInspectionContext | None = None
