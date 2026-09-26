import random
from datetime import datetime, timezone
from decimal import Decimal

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from fastapi.responses import JSONResponse
from sqlalchemy import func, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.alert import Alert
from app.models.inspection import Inspection
from app.models.inspector import Inspector
from app.models.media import Media
from app.models.project import Project
from app.models.video_session import VideoSession
from app.schemas.inspection import (
    InspectionAssignmentCreate,
    InspectionAssignmentResponse,
    InspectionAssignmentStatus,
    InspectionCreate,
    InspectionLocationResponse,
    InspectionLocationSubmit,
    InspectionResponse,
    InspectionStatus,
    InspectionStatusUpdate,
    InspectionUpdate,
)
from app.schemas.media import MediaResponse
from app.schemas.video_session import VideoSessionResponse
from app.services.audit_log_service import create_audit_log
from app.services.cloudinary_service import upload_media_to_cloudinary, validate_media_upload
from app.services.location_verification import verify_location_against_project
from app.services.notification_service import (
    notify_inspection_assigned,
    notify_inspection_created,
    notify_inspection_status_changed,
)


router = APIRouter(prefix="/inspections", tags=["Inspections"])


def get_project_or_404(project_id: int, db: Session) -> Project:
    project = db.get(Project, project_id)
    if project is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    return project


def get_inspection_or_404(inspection_id: int, db: Session) -> Inspection:
    inspection = db.get(Inspection, inspection_id)
    if inspection is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inspection not found")
    return inspection


def has_active_inspection_for_project(project_id: int, db: Session) -> bool:
    active_statuses = ["PENDING", "SCHEDULED", "IN_PROGRESS"]
    return (
        db.scalar(
            select(Inspection.id)
            .where(Inspection.project_id == project_id)
            .where(Inspection.status.in_(active_statuses))
            .limit(1)
        )
        is not None
    )


def validate_inspection_status_transition(current_status: str, new_status: str) -> None:
    allowed_transitions = {
        "PENDING": {"SCHEDULED", "IN_PROGRESS", "CANCELLED"},
        "SCHEDULED": {"IN_PROGRESS", "CANCELLED"},
        "IN_PROGRESS": {"COMPLETED", "CANCELLED"},
        "COMPLETED": set(),
        "CANCELLED": set(),
    }

    if new_status not in allowed_transitions.get(current_status, set()):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid inspection status transition: {current_status} -> {new_status}",
        )


def apply_inspection_status_transition(inspection: Inspection, new_status: str) -> None:
    validate_inspection_status_transition(inspection.status, new_status)

    if new_status == "IN_PROGRESS" and inspection.started_at is None:
        inspection.started_at = datetime.now(timezone.utc)
    elif new_status == "COMPLETED" and inspection.completed_at is None:
        inspection.completed_at = datetime.now(timezone.utc)

    inspection.status = new_status


def validate_inspection_alert(alert_id: int | None, project_id: int, db: Session) -> Alert | None:
    if alert_id is None:
        return None
    alert = db.get(Alert, alert_id)
    if alert is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Alert not found")
    if alert.project_id != project_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Alert does not belong to the specified project",
        )
    return alert


def validate_inspector_exists(officer_id: str | None, db: Session) -> Inspector | None:
    if officer_id is None:
        return None
    normalized = officer_id.strip()
    if not normalized:
        return None
    inspector = db.scalar(
        select(Inspector).where(Inspector.inspector_id == normalized).limit(1)
    )
    if inspector is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Inspector not found",
        )
    return inspector


@router.post("", response_model=InspectionResponse, status_code=status.HTTP_201_CREATED)
def create_inspection(
    inspection_data: InspectionCreate,
    db: Session = Depends(get_db),
) -> Inspection:
    get_project_or_404(inspection_data.project_id, db)
    validate_inspection_alert(inspection_data.alert_id, inspection_data.project_id, db)
    validate_inspector_exists(inspection_data.officer_id, db)

    inspection = Inspection(**inspection_data.model_dump(exclude_none=True))
    try:
        db.add(inspection)
        db.commit()
        db.refresh(inspection)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save inspection",
        )

    create_audit_log(
        db=db,
        project_id=inspection.project_id,
        entity_type="INSPECTION",
        entity_id=inspection.id,
        action="CREATED",
        actor_id=inspection.officer_id,
        actor_name=inspection.officer_name,
    )
    notify_inspection_created(inspection, db)
    return inspection


@router.post("/random", response_model=InspectionResponse, status_code=status.HTTP_201_CREATED)
def create_random_inspection(db: Session = Depends(get_db)) -> Inspection:
    active_statuses = ["PENDING", "SCHEDULED", "IN_PROGRESS"]

    eligible_projects = db.scalars(
        select(Project.id)
        .where(
            ~select(Inspection.id)
            .where(Inspection.project_id == Project.id)
            .where(Inspection.status.in_(active_statuses))
            .exists()
        )
        .order_by(func.random())
    ).all()

    if not eligible_projects:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No eligible project available for random inspection",
        )

    project_id = random.choice(eligible_projects)
    inspection = Inspection(project_id=project_id, inspection_type="RANDOM", status="PENDING")
    try:
        db.add(inspection)
        db.commit()
        db.refresh(inspection)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save inspection",
        )

    create_audit_log(
        db=db,
        project_id=inspection.project_id,
        entity_type="INSPECTION",
        entity_id=inspection.id,
        action="CREATED",
        actor_id=inspection.officer_id,
        actor_name=inspection.officer_name,
    )
    notify_inspection_created(inspection, db)
    return inspection


@router.post("/from-alert/{alert_id}", response_model=InspectionResponse, status_code=status.HTTP_201_CREATED)
def create_inspection_from_alert(alert_id: int, db: Session = Depends(get_db)) -> Inspection:
    alert = db.get(Alert, alert_id)
    if alert is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Alert not found")

    get_project_or_404(alert.project_id, db)
    if has_active_inspection_for_project(alert.project_id, db):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Project already has an active inspection",
        )

    inspection = Inspection(
        project_id=alert.project_id,
        alert_id=alert.id,
        inspection_type="ALERT_TRIGGERED",
        status="PENDING",
        reason=f"Inspection triggered by alert: {alert.message}",
    )
    try:
        db.add(inspection)
        db.commit()
        db.refresh(inspection)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save inspection",
        )

    create_audit_log(
        db=db,
        project_id=inspection.project_id,
        entity_type="INSPECTION",
        entity_id=inspection.id,
        action="CREATED",
        actor_id=inspection.officer_id,
        actor_name=inspection.officer_name,
    )
    notify_inspection_created(inspection, db)
    return inspection


@router.post("/{inspection_id}/video-session", response_model=VideoSessionResponse, status_code=status.HTTP_201_CREATED)
def create_video_session_for_inspection(
    inspection_id: int,
    db: Session = Depends(get_db),
) -> VideoSession:
    inspection = get_inspection_or_404(inspection_id, db)
    get_project_or_404(inspection.project_id, db)

    existing_session = db.scalar(
        select(VideoSession)
        .where(VideoSession.inspection_id == inspection_id)
        .limit(1)
    )
    if existing_session is not None:
        try:
            inspection.video_session_id = existing_session.session_id
            db.commit()
        except SQLAlchemyError:
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to link existing video session to inspection",
            )
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content=VideoSessionResponse.model_validate(existing_session).model_dump(mode="json"),
        )

    session = VideoSession(
        project_id=inspection.project_id,
        inspection_id=inspection.id,
        session_id=str(__import__("uuid").uuid4()),
        status="CREATED",
    )
    try:
        db.add(session)
        db.commit()
        db.refresh(session)

        inspection.video_session_id = session.session_id
        db.commit()
        db.refresh(inspection)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save video session for inspection",
        )
    return session


@router.get("/{inspection_id}/video-session", response_model=VideoSessionResponse)
def get_inspection_video_session(
    inspection_id: int,
    db: Session = Depends(get_db),
) -> VideoSession:
    get_inspection_or_404(inspection_id, db)
    video_session = db.scalar(
        select(VideoSession)
        .where(VideoSession.inspection_id == inspection_id)
        .limit(1)
    )
    if video_session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Video session not found for inspection",
        )
    return video_session


@router.post("/{inspection_id}/location", response_model=InspectionLocationResponse)
def submit_inspection_location(
    inspection_id: int,
    location_data: InspectionLocationSubmit,
    db: Session = Depends(get_db),
) -> InspectionLocationResponse:
    inspection = get_inspection_or_404(inspection_id, db)
    project = get_project_or_404(inspection.project_id, db)

    if project.latitude is None or project.longitude is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Project GPS coordinates are missing",
        )

    captured_at = location_data.location_captured_at or datetime.now(timezone.utc)
    distance_meters, is_verified = verify_location_against_project(
        project.latitude,
        project.longitude,
        location_data.latitude,
        location_data.longitude,
    )

    inspection.inspection_latitude = location_data.latitude
    inspection.inspection_longitude = location_data.longitude
    inspection.location_accuracy = location_data.location_accuracy
    inspection.location_captured_at = captured_at
    inspection.location_verified = is_verified
    inspection.distance_from_project = (
        Decimal(str(distance_meters)) if distance_meters is not None else None
    )

    try:
        db.commit()
        db.refresh(inspection)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save inspection location",
        )
    return InspectionLocationResponse(
        inspection_id=inspection.id,
        project_id=inspection.project_id,
        inspection_latitude=inspection.inspection_latitude,
        inspection_longitude=inspection.inspection_longitude,
        location_accuracy=inspection.location_accuracy,
        location_captured_at=inspection.location_captured_at,
        location_verified=inspection.location_verified,
        distance_from_project=inspection.distance_from_project,
    )


@router.get("/{inspection_id}/location", response_model=InspectionLocationResponse)
def get_inspection_location(
    inspection_id: int,
    db: Session = Depends(get_db),
) -> InspectionLocationResponse:
    inspection = get_inspection_or_404(inspection_id, db)
    return InspectionLocationResponse(
        inspection_id=inspection.id,
        project_id=inspection.project_id,
        inspection_latitude=inspection.inspection_latitude,
        inspection_longitude=inspection.inspection_longitude,
        location_accuracy=inspection.location_accuracy,
        location_captured_at=inspection.location_captured_at,
        location_verified=inspection.location_verified,
        distance_from_project=inspection.distance_from_project,
    )


@router.get("/{inspection_id}", response_model=InspectionResponse)
def get_inspection(
    inspection_id: int,
    db: Session = Depends(get_db),
) -> Inspection:
    return get_inspection_or_404(inspection_id, db)


@router.post("/{inspection_id}/evidence", response_model=MediaResponse, status_code=status.HTTP_201_CREATED)
def submit_inspection_evidence(
    inspection_id: int,
    file: UploadFile = File(...),
    description: str | None = Form(default=None),
    captured_at: str | None = Form(default=None),
    latitude: str | None = Form(default=None),
    longitude: str | None = Form(default=None),
    location_accuracy: str | None = Form(default=None),
    db: Session = Depends(get_db),
) -> Media:
    inspection = get_inspection_or_404(inspection_id, db)
    if file is None or file.filename is None or not file.filename.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Media file is required")

    try:
        file.file.seek(0, 2)
        file_size = file.file.tell()
        file.file.seek(0)
    except (AttributeError, OSError):
        file_size = 0

    if file_size <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Media file is empty")

    try:
        validate_media_upload(file.file, file.filename, file.content_type, file_size)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    if latitude is not None:
        latitude_value = Decimal(latitude)
        if latitude_value < Decimal("-90") or latitude_value > Decimal("90"):
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Latitude must be between -90 and 90")
    else:
        latitude_value = None

    if longitude is not None:
        longitude_value = Decimal(longitude)
        if longitude_value < Decimal("-180") or longitude_value > Decimal("180"):
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Longitude must be between -180 and 180")
    else:
        longitude_value = None

    if location_accuracy is not None:
        location_accuracy_value = Decimal(location_accuracy)
        if location_accuracy_value < Decimal("0"):
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="location_accuracy must be non-negative")
    else:
        location_accuracy_value = None

    parsed_captured_at = None
    if captured_at:
        try:
            parsed_captured_at = datetime.fromisoformat(captured_at)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="captured_at must be a valid ISO-8601 datetime",
            ) from exc

    try:
        upload_result = upload_media_to_cloudinary(
            file_obj=file.file,
            filename=file.filename,
            project_id=inspection.project_id,
            inspection_id=inspection.id,
            content_type=file.content_type,
            file_size=file_size,
        )
    except (RuntimeError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to upload media to Cloudinary",
        ) from None

    media = Media(
        project_id=inspection.project_id,
        inspection_id=inspection.id,
        media_type=upload_result["media_type"],
        source_type=upload_result["source_type"],
        storage_provider=upload_result["storage_provider"],
        storage_public_id=upload_result["storage_public_id"],
        media_url=upload_result["media_url"],
        original_filename=upload_result["original_filename"],
        mime_type=upload_result["mime_type"],
        file_size=int(upload_result["file_size"]),
        description=description,
        captured_at=parsed_captured_at,
        latitude=latitude_value,
        longitude=longitude_value,
        location_accuracy=location_accuracy_value,
    )
    try:
        db.add(media)
        db.commit()
        db.refresh(media)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save inspection evidence",
        )
    return media


@router.get("/{inspection_id}/evidence", response_model=list[MediaResponse])
def list_inspection_evidence(
    inspection_id: int,
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[Media]:
    get_inspection_or_404(inspection_id, db)
    statement = (
        select(Media)
        .where(Media.inspection_id == inspection_id)
        .order_by(Media.created_at.desc(), Media.id.desc())
        .limit(limit)
        .offset(offset)
    )
    return list(db.scalars(statement).all())


@router.post("/{inspection_id}/assign", response_model=InspectionResponse)
def assign_inspector_to_inspection(
    inspection_id: int,
    assignment_data: InspectionAssignmentCreate,
    db: Session = Depends(get_db),
) -> Inspection:
    inspection = get_inspection_or_404(inspection_id, db)
    if inspection.status in {"COMPLETED", "CANCELLED"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inspection is not assignable in its current status",
        )

    inspector_id = assignment_data.normalized_inspector_id
    if not inspector_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="inspector_id cannot be blank",
        )

    existing_inspector = validate_inspector_exists(inspector_id, db)

    inspector_name = assignment_data.normalized_inspector_name
    target_status = assignment_data.assignment_status.value

    if inspection.officer_id == inspector_id and inspection.officer_name == inspector_name:
        inspection.assignment_status = target_status
        if target_status == "ASSIGNED" and inspection.assigned_at is None:
            inspection.assigned_at = datetime.now(timezone.utc)
        if target_status == "UNASSIGNED":
            inspection.assigned_at = None
        try:
            db.commit()
            db.refresh(inspection)
        except SQLAlchemyError:
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to assign inspector to inspection",
            )

        create_audit_log(
            db=db,
            project_id=inspection.project_id,
            entity_type="INSPECTION",
            entity_id=inspection.id,
            action="ASSIGNED",
            actor_id=inspection.officer_id,
            actor_name=inspection.officer_name,
        )
        notify_inspection_assigned(inspection, db)
        return inspection

    inspection.officer_id = inspector_id
    inspection.officer_name = inspector_name
    inspection.assignment_status = target_status
    inspection.assigned_at = datetime.now(timezone.utc) if target_status == "ASSIGNED" else None

    try:
        db.commit()
        db.refresh(inspection)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to assign inspector to inspection",
        )

    create_audit_log(
        db=db,
        project_id=inspection.project_id,
        entity_type="INSPECTION",
        entity_id=inspection.id,
        action="ASSIGNED",
        actor_id=inspection.officer_id,
        actor_name=inspection.officer_name,
    )
    notify_inspection_assigned(inspection, db)
    return inspection


@router.get("/{inspection_id}/assignment", response_model=InspectionAssignmentResponse)
def get_inspection_assignment(
    inspection_id: int,
    db: Session = Depends(get_db),
) -> InspectionAssignmentResponse:
    inspection = get_inspection_or_404(inspection_id, db)
    assignment_status = inspection.assignment_status or InspectionAssignmentStatus.UNASSIGNED.value
    return InspectionAssignmentResponse(
        inspection_id=inspection.id,
        inspector_id=inspection.officer_id,
        inspector_name=inspection.officer_name,
        assigned_at=inspection.assigned_at,
        assignment_status=InspectionAssignmentStatus(assignment_status),
    )


@router.post("/{inspection_id}/assign-random", response_model=InspectionResponse)
def assign_random_inspector_to_inspection(
    inspection_id: int,
    db: Session = Depends(get_db),
) -> Inspection:
    inspection = get_inspection_or_404(inspection_id, db)
    if inspection.status in {"COMPLETED", "CANCELLED"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inspection is not assignable in its current status",
        )

    active_inspectors = db.scalars(
        select(Inspector)
        .where(Inspector.is_active.is_(True))
        .order_by(Inspector.id.asc())
    ).all()

    if not active_inspectors:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active inspectors available for random assignment",
        )

    selected_inspector = random.choice(active_inspectors)
    inspection.officer_id = selected_inspector.inspector_id
    inspection.officer_name = selected_inspector.inspector_name
    inspection.assignment_status = InspectionAssignmentStatus.ASSIGNED.value
    inspection.assigned_at = datetime.now(timezone.utc)

    try:
        db.commit()
        db.refresh(inspection)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to assign random inspector to inspection",
        )

    create_audit_log(
        db=db,
        project_id=inspection.project_id,
        entity_type="INSPECTION",
        entity_id=inspection.id,
        action="RANDOMLY_ASSIGNED",
        actor_id=selected_inspector.inspector_id,
        actor_name=selected_inspector.inspector_name,
    )
    notify_inspection_assigned(inspection, db, random_assignment=True)
    return inspection


@router.get("/project/{project_id}", response_model=list[InspectionResponse])
def list_project_inspections(
    project_id: int,
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[Inspection]:
    get_project_or_404(project_id, db)

    statement = (
        select(Inspection)
        .where(Inspection.project_id == project_id)
        .order_by(Inspection.created_at.desc(), Inspection.id.desc())
        .limit(limit)
        .offset(offset)
    )
    return list(db.scalars(statement).all())


@router.put("/{inspection_id}/status", response_model=InspectionResponse)
def update_inspection_status(
    inspection_id: int,
    status_data: InspectionStatusUpdate,
    db: Session = Depends(get_db),
) -> Inspection:
    inspection = get_inspection_or_404(inspection_id, db)
    previous_status = inspection.status
    target_status = status_data.status.value
    apply_inspection_status_transition(inspection, target_status)

    try:
        db.commit()
        db.refresh(inspection)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update inspection status",
        )

    if previous_status != target_status:
        create_audit_log(
            db=db,
            project_id=inspection.project_id,
            entity_type="INSPECTION",
            entity_id=inspection.id,
            action="STATUS_CHANGED",
            actor_id=inspection.officer_id,
            actor_name=inspection.officer_name,
            details=f"Status changed from {previous_status} to {target_status}",
        )

    notify_inspection_status_changed(inspection, db, previous_status=previous_status)
    return inspection


@router.put("/{inspection_id}", response_model=InspectionResponse)
def update_inspection(
    inspection_id: int,
    inspection_data: InspectionUpdate,
    db: Session = Depends(get_db),
) -> Inspection:
    inspection = get_inspection_or_404(inspection_id, db)
    updates = inspection_data.model_dump(exclude_unset=True)
    previous_status: str | None = None

    if "status" in updates and updates["status"] is not None:
        previous_status = inspection.status
        new_status = updates["status"].value if isinstance(updates["status"], InspectionStatus) else updates["status"]
        apply_inspection_status_transition(inspection, new_status)
        updates.pop("status")

    target_project_id = updates.get("project_id", inspection.project_id)
    target_alert_id = updates["alert_id"] if "alert_id" in updates else inspection.alert_id
    if target_alert_id is not None and ("alert_id" in updates or "project_id" in updates):
        validate_inspection_alert(target_alert_id, target_project_id, db)

    if "officer_id" in updates and updates["officer_id"] is not None:
        validate_inspector_exists(updates["officer_id"], db)

    for field, value in updates.items():
        setattr(inspection, field, value)

    try:
        db.commit()
        db.refresh(inspection)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update inspection",
        )

    if previous_status is not None and previous_status != inspection.status:
        create_audit_log(
            db=db,
            project_id=inspection.project_id,
            entity_type="INSPECTION",
            entity_id=inspection.id,
            action="STATUS_CHANGED",
            actor_id=inspection.officer_id,
            actor_name=inspection.officer_name,
            details=f"Status changed from {previous_status} to {inspection.status}",
        )

    if previous_status is not None:
        notify_inspection_status_changed(inspection, db, previous_status=previous_status)
    return inspection
