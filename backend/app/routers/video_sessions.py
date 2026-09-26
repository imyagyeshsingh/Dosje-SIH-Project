from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.inspection import Inspection
from app.models.project import Project
from app.models.video_session import VideoSession
from app.schemas.video_session import (
    VideoSessionCreate,
    VideoSessionResponse,
    VideoSessionStatus,
    VideoSessionUpdate,
)

router = APIRouter(prefix="/video-sessions", tags=["Video Sessions"])


def get_project_or_404(project_id: int, db: Session) -> Project:
    project = db.get(Project, project_id)
    if project is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    return project


def get_video_session_or_404(video_session_id: int, db: Session) -> VideoSession:
    video_session = db.get(VideoSession, video_session_id)
    if video_session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Video session not found",
        )
    return video_session


def validate_video_session_link(project_id: int, inspection_id: int | None, db: Session) -> None:
    if inspection_id is None:
        return

    inspection = db.get(Inspection, inspection_id)
    if inspection is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inspection not found")

    if inspection.project_id != project_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inspection does not belong to the specified project",
        )


def validate_transition(current_status: str, next_status: str) -> None:
    allowed_transitions = {
        "CREATED": {"ACTIVE", "CANCELLED"},
        "ACTIVE": {"ENDED"},
        "ENDED": set(),
        "CANCELLED": set(),
    }

    if next_status not in allowed_transitions.get(current_status, set()):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid video session transition: {current_status} -> {next_status}",
        )


@router.post("", response_model=VideoSessionResponse, status_code=status.HTTP_201_CREATED)
def create_video_session(
    video_session_data: VideoSessionCreate,
    db: Session = Depends(get_db),
) -> VideoSession:
    get_project_or_404(video_session_data.project_id, db)
    validate_video_session_link(
        video_session_data.project_id,
        video_session_data.inspection_id,
        db,
    )

    if video_session_data.inspection_id is not None:
        existing_session = db.scalar(
            select(VideoSession)
            .where(VideoSession.inspection_id == video_session_data.inspection_id)
            .limit(1)
        )
        if existing_session is not None:
            try:
                inspection = db.get(Inspection, video_session_data.inspection_id)
                if inspection is not None:
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
        project_id=video_session_data.project_id,
        inspection_id=video_session_data.inspection_id,
        session_id=str(__import__("uuid").uuid4()),
        status=VideoSessionStatus.CREATED.value,
        officer_name=video_session_data.officer_name,
        representative_name=video_session_data.representative_name,
    )
    try:
        db.add(session)
        db.commit()
        db.refresh(session)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save video session",
        )

    if session.inspection_id is not None:
        try:
            inspection = db.get(Inspection, session.inspection_id)
            if inspection is not None:
                inspection.video_session_id = session.session_id
                db.commit()
        except SQLAlchemyError:
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to link video session to inspection",
            )

    return session


@router.get("/{video_session_id}", response_model=VideoSessionResponse)
def get_video_session(
    video_session_id: int,
    db: Session = Depends(get_db),
) -> VideoSession:
    return get_video_session_or_404(video_session_id, db)


@router.get("/project/{project_id}", response_model=list[VideoSessionResponse])
def list_project_video_sessions(
    project_id: int,
    limit: int = Query(default=50, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[VideoSession]:
    get_project_or_404(project_id, db)
    statement = (
        select(VideoSession)
        .where(VideoSession.project_id == project_id)
        .order_by(VideoSession.created_at.desc(), VideoSession.id.desc())
        .limit(limit)
        .offset(offset)
    )
    return list(db.scalars(statement).all())


@router.put("/{video_session_id}", response_model=VideoSessionResponse)
def update_video_session(
    video_session_id: int,
    video_session_data: VideoSessionUpdate,
    db: Session = Depends(get_db),
) -> VideoSession:
    session = get_video_session_or_404(video_session_id, db)
    updates = video_session_data.model_dump(exclude_unset=True)

    for field, value in updates.items():
        setattr(session, field, value)

    try:
        db.commit()
        db.refresh(session)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update video session",
        )
    return session


@router.post("/{video_session_id}/start", response_model=VideoSessionResponse)
def start_video_session(
    video_session_id: int,
    db: Session = Depends(get_db),
) -> VideoSession:
    session = get_video_session_or_404(video_session_id, db)
    validate_transition(session.status, VideoSessionStatus.ACTIVE.value)
    if session.started_at is None:
        session.started_at = datetime.now(timezone.utc)
    session.status = VideoSessionStatus.ACTIVE.value
    try:
        db.commit()
        db.refresh(session)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to start video session",
        )
    return session


@router.post("/{video_session_id}/end", response_model=VideoSessionResponse)
def end_video_session(
    video_session_id: int,
    db: Session = Depends(get_db),
) -> VideoSession:
    session = get_video_session_or_404(video_session_id, db)
    validate_transition(session.status, VideoSessionStatus.ENDED.value)
    if session.ended_at is None:
        session.ended_at = datetime.now(timezone.utc)
    session.status = VideoSessionStatus.ENDED.value
    try:
        db.commit()
        db.refresh(session)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to end video session",
        )
    return session


@router.post("/{video_session_id}/cancel", response_model=VideoSessionResponse)
def cancel_video_session(
    video_session_id: int,
    db: Session = Depends(get_db),
) -> VideoSession:
    session = get_video_session_or_404(video_session_id, db)
    validate_transition(session.status, VideoSessionStatus.CANCELLED.value)
    session.status = VideoSessionStatus.CANCELLED.value
    try:
        db.commit()
        db.refresh(session)
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to cancel video session",
        )
    return session
