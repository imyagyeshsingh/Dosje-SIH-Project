from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class VideoSession(Base):
    __tablename__ = "video_sessions"

    __table_args__ = (
        CheckConstraint(
            "status IN ('CREATED', 'ACTIVE', 'ENDED', 'CANCELLED')",
            name="ck_video_sessions_status",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    project_id: Mapped[int] = mapped_column(
        ForeignKey("projects.id"), nullable=False, index=True
    )
    inspection_id: Mapped[int | None] = mapped_column(
        ForeignKey("inspections.id"), nullable=True, index=True
    )
    session_id: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    status: Mapped[str] = mapped_column(
        String(20), default="CREATED", server_default="CREATED", nullable=False
    )
    officer_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    representative_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    project: Mapped["Project"] = relationship()
    inspection: Mapped["Inspection | None"] = relationship()
