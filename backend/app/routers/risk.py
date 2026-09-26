from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.ai_detection import AIDetection
from app.models.attendance import Attendance
from app.models.camera import Camera
from app.models.project import Project
from app.routers.attendance import get_latest_detection
from app.schemas.risk import RiskLevel, RiskResponse


router = APIRouter(prefix="/risk", tags=["Risk"])

# Signal weights (percent of the weighted average).
ATTENDANCE_WEIGHT = 40
PROGRESS_WEIGHT = 25
CCTV_WEIGHT = 20
ACTIVITY_WEIGHT = 15

ACTIVITY_RISK_VALUES: dict[str, int] = {
    "NORMAL": 0,
    "LOW": 30,
    "NO_ACTIVITY": 60,
    "HIGH": 70,
    "SUSPICIOUS": 100,
}


def get_project_or_404(project_id: int, db: Session) -> Project:
    project = db.get(Project, project_id)
    if project is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    return project


def attendance_risk_value(
    attendance: Attendance | None, latest_detection: AIDetection | None
) -> int | None:
    """Unavailable without attendance config, a detection, or a positive expected_workers."""
    if attendance is None or latest_detection is None:
        return None

    expected_workers = attendance.expected_workers
    if expected_workers is None or expected_workers <= 0:
        return None

    percentage = round(latest_detection.people_detected / expected_workers * 100, 2)
    if percentage >= 90:
        return 0
    if percentage >= 75:
        return 30
    if percentage >= 50:
        return 60
    return 100


def progress_risk_value(progress: Decimal | None) -> int | None:
    if progress is None:
        return None

    value = float(progress)
    if value >= 80:
        return 0
    if value >= 60:
        return 25
    if value >= 40:
        return 50
    if value >= 20:
        return 75
    return 100


def cctv_risk_from_ratio(active_ratio: float) -> int:
    if active_ratio >= 0.90:
        return 0
    if active_ratio >= 0.75:
        return 25
    if active_ratio >= 0.50:
        return 60
    return 100


def cctv_risk_value(project_id: int, db: Session) -> int | None:
    statuses = db.scalars(select(Camera.status).where(Camera.project_id == project_id)).all()
    total_cameras = len(statuses)
    if total_cameras == 0:
        return None

    active_cameras = sum(1 for camera_status in statuses if camera_status == "ACTIVE")
    return cctv_risk_from_ratio(active_cameras / total_cameras)


def activity_risk_value(latest_detection: AIDetection | None) -> int | None:
    """Case-insensitive/trimmed lookup; unknown activity means the signal is unavailable."""
    if latest_detection is None or latest_detection.activity is None:
        return None

    return ACTIVITY_RISK_VALUES.get(latest_detection.activity.strip().upper())


def risk_level_for_score(score: int) -> RiskLevel:
    if score >= 80:
        return RiskLevel.CRITICAL
    if score >= 60:
        return RiskLevel.HIGH
    if score >= 30:
        return RiskLevel.MEDIUM
    return RiskLevel.LOW


def calculate_project_risk(project: Project, db: Session) -> RiskResponse:
    """Single risk authority, shared by GET /risk/{project_id} and the project summary."""
    latest_detection = get_latest_detection(project.id, db)
    attendance = db.scalars(select(Attendance).where(Attendance.project_id == project.id)).first()

    signals = (
        (attendance_risk_value(attendance, latest_detection), ATTENDANCE_WEIGHT),
        (progress_risk_value(project.progress), PROGRESS_WEIGHT),
        (cctv_risk_value(project.id, db), CCTV_WEIGHT),
        (activity_risk_value(latest_detection), ACTIVITY_WEIGHT),
    )
    available_signals = [(value, weight) for value, weight in signals if value is not None]

    if not available_signals:
        return RiskResponse()

    total_weight = sum(weight for _, weight in available_signals)
    weighted_total = sum(value * weight for value, weight in available_signals)
    score = round(weighted_total / total_weight)

    return RiskResponse(score=score, level=risk_level_for_score(score))


@router.get("/{project_id}", response_model=RiskResponse)
def get_project_risk(project_id: int, db: Session = Depends(get_db)) -> RiskResponse:
    project = get_project_or_404(project_id, db)
    return calculate_project_risk(project, db)
