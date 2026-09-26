from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class AIDetection(Base):
    __tablename__ = "ai_detections"

    __table_args__ = (
        CheckConstraint("people_detected >= 0", name="ck_ai_detections_people_detected"),
        CheckConstraint(
            "confidence >= 0 AND confidence <= 1",
            name="ck_ai_detections_confidence",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    project_id: Mapped[int] = mapped_column(
        ForeignKey("projects.id"), nullable=False, index=True
    )
    camera_id: Mapped[int] = mapped_column(
        ForeignKey("cameras.id"), nullable=False, index=True
    )
    people_detected: Mapped[int] = mapped_column(nullable=False, default=0)
    activity: Mapped[str] = mapped_column(String(50), nullable=False)
    confidence: Mapped[float] = mapped_column(Numeric(5, 4), nullable=False)
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    project: Mapped["Project"] = relationship()
    camera: Mapped["Camera"] = relationship()
