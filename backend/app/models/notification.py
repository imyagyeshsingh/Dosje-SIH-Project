from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Notification(Base):
    __tablename__ = "notifications"

    __table_args__ = (
        CheckConstraint(
            "notification_type IN ('ALERT', 'INSPECTION', 'ASSIGNMENT', 'REPORT', 'VIDEO_SESSION', 'SYSTEM')",
            name="ck_notifications_notification_type",
        ),
        CheckConstraint(
            "severity IS NULL OR severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')",
            name="ck_notifications_severity",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    project_id: Mapped[int] = mapped_column(
        ForeignKey("projects.id"), nullable=False, index=True
    )
    recipient_id: Mapped[str | None] = mapped_column(String(100), nullable=True, index=True)
    recipient_role: Mapped[str | None] = mapped_column(String(50), nullable=True)
    notification_type: Mapped[str] = mapped_column(String(50), nullable=False)
    severity: Mapped[str | None] = mapped_column(String(20), nullable=True)
    title: Mapped[str | None] = mapped_column(String(255), nullable=True)
    message: Mapped[str] = mapped_column(String(500), nullable=False)
    source: Mapped[str] = mapped_column(String(50), nullable=False)
    alert_id: Mapped[int | None] = mapped_column(
        ForeignKey("alerts.id"), nullable=True, index=True
    )
    inspection_id: Mapped[int | None] = mapped_column(
        ForeignKey("inspections.id"), nullable=True, index=True
    )
    is_read: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default="0",
        nullable=False,
    )
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    project: Mapped["Project"] = relationship()
    alert: Mapped["Alert | None"] = relationship()
    inspection: Mapped["Inspection | None"] = relationship()
