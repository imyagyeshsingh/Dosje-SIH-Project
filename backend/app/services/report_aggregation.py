from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.ai_detection import AIDetection
from app.models.alert import Alert
from app.models.attendance import Attendance
from app.models.camera import Camera
from app.models.inspection import Inspection
from app.models.project import Project
from app.models.report import Report
from app.models.report_evidence_reference import ReportEvidenceReference
from app.models.video_session import VideoSession
from app.routers.attendance import get_latest_detection
from app.routers.risk import calculate_project_risk


def aggregate_report_data(report: Report, db: Session) -> dict:
    project = db.get(Project, report.project_id)
    if project is None:
        raise ValueError("Project not found for report")

    risk = calculate_project_risk(project, db)

    attendance = db.scalars(
        select(Attendance).where(Attendance.project_id == project.id)
    ).first()
    latest_detection = get_latest_detection(project.id, db)
    expected_workers = attendance.expected_workers if attendance is not None else None
    detected_workers = latest_detection.people_detected if latest_detection is not None else None
    attendance_percentage = None
    if expected_workers is not None and expected_workers > 0 and detected_workers is not None:
        attendance_percentage = round(detected_workers / expected_workers * 100, 2)

    cameras = list(db.scalars(select(Camera).where(Camera.project_id == project.id)).all())
    total_cameras = len(cameras)
    active_cameras = sum(1 for camera in cameras if camera.status == "ACTIVE")

    ai_detections = list(
        db.scalars(
            select(AIDetection)
            .where(AIDetection.project_id == project.id)
            .order_by(AIDetection.timestamp.desc(), AIDetection.id.desc())
        ).all()
    )
    total_ai = len(ai_detections)
    latest_ai = ai_detections[0] if ai_detections else None

    total_alerts = db.scalar(
        select(func.count()).select_from(Alert).where(Alert.project_id == project.id)
    ) or 0
    active_alerts = db.scalar(
        select(func.count())
        .select_from(Alert)
        .where(Alert.project_id == project.id)
        .where(Alert.status.in_(["OPEN", "ACKNOWLEDGED"]))
    ) or 0
    resolved_alerts = db.scalar(
        select(func.count())
        .select_from(Alert)
        .where(Alert.project_id == project.id)
        .where(Alert.status == "RESOLVED")
    ) or 0

    inspections = list(db.scalars(select(Inspection).where(Inspection.project_id == project.id)).all())
    inspection_counts = {
        "total_inspections": len(inspections),
        "pending": sum(1 for inspection in inspections if inspection.status == "PENDING"),
        "scheduled": sum(1 for inspection in inspections if inspection.status == "SCHEDULED"),
        "in_progress": sum(1 for inspection in inspections if inspection.status == "IN_PROGRESS"),
        "completed": sum(1 for inspection in inspections if inspection.status == "COMPLETED"),
        "cancelled": sum(1 for inspection in inspections if inspection.status == "CANCELLED"),
    }
    latest_inspection = max(inspections, key=lambda item: (item.created_at, item.id), default=None)

    video_sessions = list(
        db.scalars(
            select(VideoSession)
            .where(VideoSession.project_id == project.id)
            .order_by(VideoSession.created_at.desc(), VideoSession.id.desc())
        ).all()
    )
    total_sessions = len(video_sessions)
    active_sessions = sum(1 for session in video_sessions if session.status == "ACTIVE")
    ended_sessions = sum(1 for session in video_sessions if session.status == "ENDED")
    latest_session = video_sessions[0] if video_sessions else None

    evidence_ids = [
        item.external_evidence_id
        for item in db.scalars(
            select(ReportEvidenceReference)
            .join(Report, Report.id == ReportEvidenceReference.report_id)
            .where(Report.project_id == project.id)
            .order_by(ReportEvidenceReference.created_at.desc(), ReportEvidenceReference.id.desc())
        ).all()
    ]

    report_inspection = None
    if report.inspection_id is not None:
        inspection = db.get(Inspection, report.inspection_id)
        if inspection is not None:
            report_inspection = {
                "id": inspection.id,
                "inspection_type": inspection.inspection_type,
                "status": inspection.status,
                "officer_name": inspection.officer_name,
                "reason": inspection.reason,
            }

    return {
        "report_id": report.id,
        "project_id": project.id,
        "project_name": project.project_name,
        "project_code": project.project_code,
        "risk": {
            "score": risk.score,
            "level": risk.level.value if risk.level is not None else None,
        },
        "attendance": {
            "expected_workers": expected_workers,
            "detected_workers": detected_workers,
            "attendance_percentage": attendance_percentage,
            "detection_timestamp": latest_detection.timestamp if latest_detection is not None else None,
        },
        "cctv": {
            "total_cameras": total_cameras,
            "active_cameras": active_cameras,
        },
        "ai": {
            "total_detections": total_ai,
            "latest_detection_id": latest_ai.id if latest_ai is not None else None,
            "latest_activity": latest_ai.activity if latest_ai is not None else None,
            "latest_people_detected": latest_ai.people_detected if latest_ai is not None else None,
            "latest_confidence": float(latest_ai.confidence) if latest_ai is not None else None,
            "latest_timestamp": latest_ai.timestamp if latest_ai is not None else None,
        },
        "alerts": {
            "total_alerts": total_alerts,
            "active_alerts": active_alerts,
            "resolved_alerts": resolved_alerts,
        },
        "inspections": {
            **inspection_counts,
            "latest_inspection_id": latest_inspection.id if latest_inspection is not None else None,
            "latest_inspection_status": latest_inspection.status if latest_inspection is not None else None,
        },
        "video_sessions": {
            "total_sessions": total_sessions,
            "active_sessions": active_sessions,
            "ended_sessions": ended_sessions,
            "latest_session_id": latest_session.id if latest_session is not None else None,
            "latest_session_status": latest_session.status if latest_session is not None else None,
        },
        "evidence": {
            "total_references": len(evidence_ids),
            "project_evidence_ids": evidence_ids,
        },
        "inspection": report_inspection,
    }
