from datetime import datetime
from decimal import Decimal

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Media(Base):
    __tablename__ = "media"

    __table_args__ = (
        CheckConstraint(
            "media_type IN ('IMAGE', 'VIDEO', 'DOCUMENT')",
            name="ck_media_media_type",
        ),
        CheckConstraint(
            "source_type IN ('UPLOAD', 'MANUAL', 'MANUAL_UPLOAD', 'AI_GENERATED')",
            name="ck_media_source_type",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    project_id: Mapped[int] = mapped_column(ForeignKey("projects.id"), nullable=False, index=True)
    inspection_id: Mapped[int | None] = mapped_column(ForeignKey("inspections.id"), nullable=True, index=True)
    camera_id: Mapped[int | None] = mapped_column(ForeignKey("cameras.id"), nullable=True, index=True)
    media_type: Mapped[str] = mapped_column(String(20), nullable=False)
    source_type: Mapped[str] = mapped_column(String(30), nullable=False)
    storage_provider: Mapped[str] = mapped_column(String(50), nullable=False, default="cloudinary")
    storage_public_id: Mapped[str] = mapped_column(String(512), nullable=False)
    media_url: Mapped[str] = mapped_column(String(2048), nullable=False)
    original_filename: Mapped[str | None] = mapped_column(String(255), nullable=True)
    mime_type: Mapped[str | None] = mapped_column(String(100), nullable=True)
    file_size: Mapped[int | None] = mapped_column(nullable=True)
    description: Mapped[str | None] = mapped_column(String(2000), nullable=True)
    captured_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    latitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    longitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    location_accuracy: Mapped[Decimal | None] = mapped_column(Numeric(9, 3), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    project: Mapped["Project"] = relationship(back_populates="media")
    inspection: Mapped["Inspection | None"] = relationship(back_populates="media")
    camera: Mapped["Camera | None"] = relationship(back_populates="media")
