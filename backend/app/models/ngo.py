from datetime import datetime
from sqlalchemy import DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class NGO(Base):
    __tablename__ = "ngos"

    id: Mapped[str] = mapped_column(String(100), primary_key=True)
    user_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    email: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    designation: Mapped[str] = mapped_column(String(255), nullable=False)
    mobile_number: Mapped[str] = mapped_column(String(50), nullable=False)
    ngo_name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    organization_type: Mapped[str] = mapped_column(String(100), nullable=False)
    registration_number: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    establishment_year: Mapped[int] = mapped_column(Integer, nullable=False, default=2020)
    contact_number: Mapped[str] = mapped_column(String(50), nullable=False)
    official_email: Mapped[str] = mapped_column(String(255), nullable=False)
    address: Mapped[str] = mapped_column(Text, nullable=False)
    state: Mapped[str] = mapped_column(String(100), nullable=False)
    district: Mapped[str] = mapped_column(String(100), nullable=False)
    city: Mapped[str] = mapped_column(String(100), nullable=False)
    pin_code: Mapped[str] = mapped_column(String(20), nullable=False)
    status: Mapped[str] = mapped_column(
        String(50), nullable=False, default="incomplete", server_default="incomplete"
    )
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    review_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    correction_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "fullName": self.full_name or "",
            "designation": self.designation or "",
            "mobileNumber": self.mobile_number or "",
            "email": self.email,
            "ngoName": self.ngo_name or "",
            "organizationType": self.organization_type or "",
            "registrationNumber": self.registration_number or "",
            "establishmentYear": self.establishment_year or 2020,
            "contactNumber": self.contact_number or "",
            "officialEmail": self.official_email or "",
            "address": self.address or "",
            "state": self.state or "",
            "district": self.district or "",
            "city": self.city or "",
            "pinCode": self.pin_code or "",
            "status": self.status or "incomplete",
            "submittedAt": self.submitted_at.isoformat() if self.submitted_at else None,
            "reviewedAt": self.reviewed_at.isoformat() if self.reviewed_at else None,
            "reviewNotes": self.review_notes,
            "correctionNotes": self.correction_notes,
            # snake_case versions
            "user_id": self.user_id,
            "full_name": self.full_name or "",
            "mobile_number": self.mobile_number or "",
            "ngo_name": self.ngo_name or "",
            "organization_type": self.organization_type or "",
            "registration_number": self.registration_number or "",
            "establishment_year": self.establishment_year or 2020,
            "contact_number": self.contact_number or "",
            "official_email": self.official_email or "",
            "pin_code": self.pin_code or "",
            "submitted_at": self.submitted_at.isoformat() if self.submitted_at else None,
            "reviewed_at": self.reviewed_at.isoformat() if self.reviewed_at else None,
            "review_notes": self.review_notes,
            "correction_notes": self.correction_notes,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
