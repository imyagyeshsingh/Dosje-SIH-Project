from datetime import datetime, timezone
import time
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, Depends, HTTPException, Header, Request, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.ngo import NGO
from app.schemas.ngo import (
    NgoApprovePayload,
    NgoCorrectionPayload,
    NgoProfilePayload,
    NgoStatusUpdatePayload,
)
from app.services.realtime import realtime_manager

router = APIRouter(tags=["NGO Registration & Official Directory"])


def extract_user_email(request: Request, x_user_email: Optional[str] = None) -> Optional[str]:
    if x_user_email and x_user_email.strip():
        return x_user_email.strip().lower()
    header_email = request.headers.get("x-user-email")
    if header_email and header_email.strip():
        return header_email.strip().lower()
    auth_header = request.headers.get("authorization", "")
    if "Bearer " in auth_header:
        token = auth_header.replace("Bearer ", "").strip()
        if "@" in token:
            parts = token.split("_")
            for part in parts:
                if "@" in part:
                    return part.strip().lower()
    return None


# ============================================================================
# NGO Portal Endpoints
# ============================================================================

@router.get("/api/v1/ngo/me")
def get_my_ngo_profile(
    request: Request,
    email: Optional[str] = None,
    x_user_email: Optional[str] = Header(None),
    db: Session = Depends(get_db),
):
    """Retrieve the current authenticated NGO representative's organization profile."""
    resolved_email = email or extract_user_email(request, x_user_email)
    if not resolved_email:
        # Check if there is an NGO or return null
        return None

    ngo = db.query(NGO).filter(NGO.email.ilike(resolved_email.strip().lower())).first()
    if not ngo:
        return None
    return ngo.to_dict()


@router.get("/api/v1/ngo/registration-status")
def get_ngo_registration_status(
    request: Request,
    email: Optional[str] = None,
    x_user_email: Optional[str] = Header(None),
    db: Session = Depends(get_db),
):
    """Check the onboarding registration status for the current NGO."""
    resolved_email = email or extract_user_email(request, x_user_email)
    if not resolved_email:
        return {"status": "incomplete"}

    ngo = db.query(NGO).filter(NGO.email.ilike(resolved_email.strip().lower())).first()
    if not ngo:
        return {"status": "incomplete"}
    return {"status": ngo.status, "ngo_id": ngo.id}


@router.post("/api/v1/ngo/profile")
@router.patch("/api/v1/ngo/profile")
async def save_or_update_ngo_profile(
    request: Request,
    payload: Optional[NgoProfilePayload] = None,
    x_user_email: Optional[str] = Header(None),
    db: Session = Depends(get_db),
):
    """Save or update the draft NGO profile."""
    # Read raw body in case payload is empty or partially formatted
    data = {}
    try:
        raw_json = await request.json()
        if isinstance(raw_json, dict):
            data = raw_json
    except Exception:
        pass

    if payload:
        model_dump = payload.model_dump(exclude_unset=True)
        data.update(model_dump)

    email = (
        data.get("email")
        or extract_user_email(request, x_user_email)
        or data.get("officialEmail")
        or data.get("official_email")
    )

    if not email:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Representative email is required to save NGO profile.",
        )

    clean_email = email.strip().lower()
    ngo_id = data.get("id") or f"ngo_{int(time.time() * 1000)}"

    existing = db.query(NGO).filter(NGO.email.ilike(clean_email)).first()
    if not existing and data.get("id"):
        existing = db.query(NGO).filter(NGO.id == data["id"]).first()

    if existing:
        if "fullName" in data or "full_name" in data:
            existing.full_name = data.get("fullName") or data.get("full_name") or existing.full_name
        if "designation" in data:
            existing.designation = data["designation"]
        if "mobileNumber" in data or "mobile_number" in data:
            existing.mobile_number = data.get("mobileNumber") or data.get("mobile_number") or existing.mobile_number
        if "ngoName" in data or "ngo_name" in data:
            existing.ngo_name = data.get("ngoName") or data.get("ngo_name") or existing.ngo_name
        if "organizationType" in data or "organization_type" in data:
            existing.organization_type = data.get("organizationType") or data.get("organization_type") or existing.organization_type
        if "registrationNumber" in data or "registration_number" in data:
            existing.registration_number = data.get("registrationNumber") or data.get("registration_number") or existing.registration_number
        if "establishmentYear" in data or "establishment_year" in data:
            existing.establishment_year = int(data.get("establishmentYear") or data.get("establishment_year") or 2020)
        if "contactNumber" in data or "contact_number" in data:
            existing.contact_number = data.get("contactNumber") or data.get("contact_number") or existing.contact_number
        if "officialEmail" in data or "official_email" in data:
            existing.official_email = data.get("officialEmail") or data.get("official_email") or existing.official_email
        if "address" in data:
            existing.address = data["address"]
        if "state" in data:
            existing.state = data["state"]
        if "district" in data:
            existing.district = data["district"]
        if "city" in data:
            existing.city = data["city"]
        if "pinCode" in data or "pin_code" in data:
            existing.pin_code = data.get("pinCode") or data.get("pin_code") or existing.pin_code
        if "status" in data and data["status"]:
            existing.status = data["status"]

        db.commit()
        db.refresh(existing)
        return existing.to_dict()

    new_ngo = NGO(
        id=ngo_id,
        user_id=f"ngo_{clean_email.split('@')[0]}",
        email=clean_email,
        full_name=data.get("fullName") or data.get("full_name") or "NGO Representative",
        designation=data.get("designation") or "Representative",
        mobile_number=data.get("mobileNumber") or data.get("mobile_number") or "",
        ngo_name=data.get("ngoName") or data.get("ngo_name") or "NGO Organization",
        organization_type=data.get("organizationType") or data.get("organization_type") or "Society",
        registration_number=data.get("registrationNumber") or data.get("registration_number") or f"REG-{int(time.time())}",
        establishment_year=int(data.get("establishmentYear") or data.get("establishment_year") or 2020),
        contact_number=data.get("contactNumber") or data.get("contact_number") or "",
        official_email=data.get("officialEmail") or data.get("official_email") or clean_email,
        address=data.get("address") or "",
        state=data.get("state") or "",
        district=data.get("district") or "",
        city=data.get("city") or "",
        pin_code=data.get("pinCode") or data.get("pin_code") or "",
        status=data.get("status") or "incomplete",
    )
    db.add(new_ngo)
    db.commit()
    db.refresh(new_ngo)
    return new_ngo.to_dict()


@router.post("/api/v1/ngo/registration/submit")
async def submit_ngo_registration(
    request: Request,
    payload: Optional[NgoProfilePayload] = None,
    x_user_email: Optional[str] = Header(None),
    db: Session = Depends(get_db),
):
    """
    Finalize and submit the NGO registration dossier.
    Sets status to 'submitted' and broadcasts a realtime WebSocket event to Official UI.
    """
    data = {}
    try:
        raw_json = await request.json()
        if isinstance(raw_json, dict):
            data = raw_json
    except Exception:
        pass

    if payload:
        model_dump = payload.model_dump(exclude_unset=True)
        data.update(model_dump)

    email = (
        data.get("email")
        or extract_user_email(request, x_user_email)
        or data.get("officialEmail")
        or data.get("official_email")
    )

    clean_email = email.strip().lower() if email else None
    existing = None

    if clean_email:
        existing = db.query(NGO).filter(NGO.email.ilike(clean_email)).first()
    if not existing and data.get("id"):
        existing = db.query(NGO).filter(NGO.id == data["id"]).first()

    now_utc = datetime.now(timezone.utc)

    if existing:
        # Update any fields present in request
        if "fullName" in data or "full_name" in data:
            existing.full_name = data.get("fullName") or data.get("full_name") or existing.full_name
        if "designation" in data:
            existing.designation = data["designation"]
        if "mobileNumber" in data or "mobile_number" in data:
            existing.mobile_number = data.get("mobileNumber") or data.get("mobile_number") or existing.mobile_number
        if "ngoName" in data or "ngo_name" in data:
            existing.ngo_name = data.get("ngoName") or data.get("ngo_name") or existing.ngo_name
        if "organizationType" in data or "organization_type" in data:
            existing.organization_type = data.get("organizationType") or data.get("organization_type") or existing.organization_type
        if "registrationNumber" in data or "registration_number" in data:
            existing.registration_number = data.get("registrationNumber") or data.get("registration_number") or existing.registration_number
        if "establishmentYear" in data or "establishment_year" in data:
            existing.establishment_year = int(data.get("establishmentYear") or data.get("establishment_year") or existing.establishment_year)
        if "contactNumber" in data or "contact_number" in data:
            existing.contact_number = data.get("contactNumber") or data.get("contact_number") or existing.contact_number
        if "officialEmail" in data or "official_email" in data:
            existing.official_email = data.get("officialEmail") or data.get("official_email") or existing.official_email
        if "address" in data:
            existing.address = data["address"]
        if "state" in data:
            existing.state = data["state"]
        if "district" in data:
            existing.district = data["district"]
        if "city" in data:
            existing.city = data["city"]
        if "pinCode" in data or "pin_code" in data:
            existing.pin_code = data.get("pinCode") or data.get("pin_code") or existing.pin_code

        existing.status = "submitted"
        existing.submitted_at = now_utc
        db.commit()
        db.refresh(existing)
        target_ngo = existing
    else:
        ngo_id = data.get("id") or f"ngo_{int(time.time() * 1000)}"
        target_ngo = NGO(
            id=ngo_id,
            user_id=f"ngo_{clean_email.split('@')[0]}" if clean_email else f"ngo_{int(time.time())}",
            email=clean_email or "ngo@example.com",
            full_name=data.get("fullName") or data.get("full_name") or "NGO Representative",
            designation=data.get("designation") or "Authorized Signatory",
            mobile_number=data.get("mobileNumber") or data.get("mobile_number") or "",
            ngo_name=data.get("ngoName") or data.get("ngo_name") or "New Registered NGO",
            organization_type=data.get("organizationType") or data.get("organization_type") or "Society",
            registration_number=data.get("registrationNumber") or data.get("registration_number") or f"REG-{int(time.time())}",
            establishment_year=int(data.get("establishmentYear") or data.get("establishment_year") or 2020),
            contact_number=data.get("contactNumber") or data.get("contact_number") or "",
            official_email=data.get("officialEmail") or data.get("official_email") or (clean_email or "ngo@example.com"),
            address=data.get("address") or "",
            state=data.get("state") or "",
            district=data.get("district") or "",
            city=data.get("city") or "",
            pin_code=data.get("pinCode") or data.get("pin_code") or "",
            status="submitted",
            submitted_at=now_utc,
        )
        db.add(target_ngo)
        db.commit()
        db.refresh(target_ngo)

    ngo_dict = target_ngo.to_dict()

    # REALTIME BROADCAST: Notify all connected Official web & mobile clients instantly!
    await realtime_manager.broadcast("NGO_REGISTERED", ngo_dict)

    return ngo_dict


# ============================================================================
# Official Directory & Review Endpoints
# ============================================================================

@router.get("/api/v1/official/ngos")
def get_all_registered_ngos(db: Session = Depends(get_db)):
    """
    Retrieve all registered NGOs for the Directorate Official's directory.
    Sorted by latest submission time first.
    """
    ngos = db.query(NGO).order_by(NGO.submitted_at.desc().nullslast(), NGO.created_at.desc()).all()
    return [ngo.to_dict() for ngo in ngos]


@router.get("/api/v1/official/ngos/{ngo_id}")
def get_ngo_details(ngo_id: str, db: Session = Depends(get_db)):
    """Retrieve complete dossier for a single NGO."""
    ngo = db.query(NGO).filter(NGO.id == ngo_id).first()
    if not ngo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"NGO with ID '{ngo_id}' not found.",
        )
    return ngo.to_dict()


@router.post("/api/v1/official/ngos/{ngo_id}/approve")
async def approve_ngo_registration(
    ngo_id: str,
    payload: Optional[NgoApprovePayload] = None,
    db: Session = Depends(get_db),
):
    """Official action: approve an NGO registration dossier."""
    ngo = db.query(NGO).filter(NGO.id == ngo_id).first()
    if not ngo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"NGO with ID '{ngo_id}' not found.",
        )

    ngo.status = "approved"
    ngo.reviewed_at = datetime.now(timezone.utc)
    ngo.review_notes = payload.notes if payload else "Approved by State Reviewing Authority."
    db.commit()
    db.refresh(ngo)

    result = ngo.to_dict()
    # Broadcast realtime status change
    await realtime_manager.broadcast("NGO_REGISTRATION_STATUS_CHANGED", result)
    return result


@router.post("/api/v1/official/ngos/{ngo_id}/correction")
async def request_ngo_correction(
    ngo_id: str,
    payload: NgoCorrectionPayload,
    db: Session = Depends(get_db),
):
    """Official action: send NGO registration back for correction with required notes."""
    ngo = db.query(NGO).filter(NGO.id == ngo_id).first()
    if not ngo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"NGO with ID '{ngo_id}' not found.",
        )

    ngo.status = "correctionRequired"
    ngo.reviewed_at = datetime.now(timezone.utc)
    ngo.correction_notes = payload.notes
    db.commit()
    db.refresh(ngo)

    result = ngo.to_dict()
    # Broadcast realtime status change
    await realtime_manager.broadcast("NGO_REGISTRATION_STATUS_CHANGED", result)
    return result


@router.post("/api/v1/official/ngos/{ngo_id}/under-review")
async def mark_ngo_under_review(
    ngo_id: str,
    payload: Optional[NgoApprovePayload] = None,
    db: Session = Depends(get_db),
):
    """Official action: mark NGO registration as under review."""
    ngo = db.query(NGO).filter(NGO.id == ngo_id).first()
    if not ngo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"NGO with ID '{ngo_id}' not found.",
        )

    ngo.status = "underReview"
    ngo.reviewed_at = datetime.now(timezone.utc)
    ngo.review_notes = payload.notes if (payload and payload.notes) else "Under review by State Reviewing Authority."
    db.commit()
    db.refresh(ngo)

    result = ngo.to_dict()
    await realtime_manager.broadcast("NGO_REGISTRATION_STATUS_CHANGED", result)
    return result


@router.post("/api/v1/official/ngos/{ngo_id}/status")
async def update_ngo_status(
    ngo_id: str,
    payload: NgoStatusUpdatePayload,
    db: Session = Depends(get_db),
):
    """Official action: update NGO registration status to approved, underReview, or correctionRequired."""
    ngo = db.query(NGO).filter(NGO.id == ngo_id).first()
    if not ngo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"NGO with ID '{ngo_id}' not found.",
        )

    valid_statuses = ["incomplete", "submitted", "underReview", "approved", "correctionRequired"]
    norm_status = payload.status
    for s in valid_statuses:
        if s.lower() == norm_status.lower():
            norm_status = s
            break

    ngo.status = norm_status
    ngo.reviewed_at = datetime.now(timezone.utc)
    if norm_status == "correctionRequired":
        ngo.correction_notes = payload.notes or "Correction requested by Directorate Official."
    else:
        ngo.review_notes = payload.notes or f"Marked as {norm_status} by Directorate Official."

    db.commit()
    db.refresh(ngo)

    result = ngo.to_dict()
    await realtime_manager.broadcast("NGO_REGISTRATION_STATUS_CHANGED", result)
    return result

