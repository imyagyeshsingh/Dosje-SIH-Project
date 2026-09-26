from datetime import datetime
from decimal import Decimal

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Inspection(Base):
    __tablename__ = "inspections"

    __table_args__ = (
        CheckConstraint(
            "inspection_type IN ('RANDOM', 'ALERT_TRIGGERED', 'SCHEDULED', 'MANUAL')",
            name="ck_inspections_inspection_type",
        ),
        CheckConstraint(
            "status IN ('PENDING', 'SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')",
            name="ck_inspections_status",
        ),
        CheckConstraint(
            "assignment_status IN ('UNASSIGNED', 'ASSIGNED')",
            name="ck_inspections_assignment_status",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    project_id: Mapped[int] = mapped_column(
        ForeignKey("projects.id"), nullable=False, index=True
    )
    alert_id: Mapped[int | None] = mapped_column(
        ForeignKey("alerts.id"), nullable=True, index=True
    )
    inspection_type: Mapped[str] = mapped_column(String(50), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False)
    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    officer_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    officer_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    assignment_status: Mapped[str] = mapped_column(
        String(20), default="UNASSIGNED", server_default="UNASSIGNED", nullable=False
    )
    assigned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    inspection_latitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    inspection_longitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    location_accuracy: Mapped[Decimal | None] = mapped_column(Numeric(9, 3), nullable=True)
    location_captured_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    location_verified: Mapped[bool] = mapped_column(default=False, server_default="0", nullable=False)
    distance_from_project: Mapped[Decimal | None] = mapped_column(Numeric(9, 3), nullable=True)
    reason: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    findings: Mapped[str | None] = mapped_column(String(2000), nullable=True)
    result: Mapped[str | None] = mapped_column(String(255), nullable=True)
    video_session_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    project: Mapped["Project"] = relationship()
    alert: Mapped["Alert | None"] = relationship()
    media: Mapped[list["Media"]] = relationship(back_populates="inspection")
