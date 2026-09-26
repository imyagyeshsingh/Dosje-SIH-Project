from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.report_evidence_reference import ReportEvidenceReference


class Report(Base):
    __tablename__ = "reports"

    __table_args__ = (
        CheckConstraint(
            "report_type IN ('INSPECTION', 'MONITORING', 'INCIDENT')",
            name="ck_reports_report_type",
        ),
        CheckConstraint(
            "status IN ('DRAFT', 'FINAL')",
            name="ck_reports_status",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    project_id: Mapped[int] = mapped_column(
        ForeignKey("projects.id"), nullable=False, index=True
    )
    inspection_id: Mapped[int] = mapped_column(
        ForeignKey("inspections.id"), nullable=False, index=True
    )
    report_type: Mapped[str] = mapped_column(String(30), nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), default="DRAFT", server_default="DRAFT", nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    summary: Mapped[str | None] = mapped_column(String(2000), nullable=True)
    findings: Mapped[str | None] = mapped_column(String(5000), nullable=True)
    recommendations: Mapped[str | None] = mapped_column(String(5000), nullable=True)
    generated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    evidence_references: Mapped[list["ReportEvidenceReference"]] = relationship(
        back_populates="report",
    )
