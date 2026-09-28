from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user_role_whitelist import UserRoleWhitelist
from app.schemas.auth import (
    ResolveRoleRequest,
    ResolveRoleResponse,
    WhitelistCreate,
    WhitelistResponse,
    SendOtpRequest,
    SendOtpResponse,
)
from app.services.clerk_auth_service import (
    ensure_seed_whitelist,
    resolve_user_role_from_db_or_seed,
)

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication & RBAC"])


@router.post("/otp/send", response_model=SendOtpResponse)
def request_otp(payload: SendOtpRequest):
    """
    Acknowledgement endpoint — OTP is handled entirely by Clerk on the client side.
    The backend does NOT generate or store any OTP. This endpoint just confirms
    the email is non-empty and returns success so the app can proceed.
    """
    if not payload.email or not payload.email.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Valid email address is required.",
        )
    return SendOtpResponse(
        success=True,
        message="Verification code will be sent to your email by Clerk.",
        email=payload.email.strip().lower(),
        expires_in=300,
        dev_otp=None,
        clerk_sent=True,
    )


@router.post("/resolve-role", response_model=ResolveRoleResponse)
def resolve_role(
    payload: ResolveRoleRequest,
    db: Session = Depends(get_db),
):
    """
    Authoritative role resolution endpoint.
    Called AFTER Clerk has verified the OTP on the client.
    Checks the email against the database whitelist and returns:
      - OFFICIAL  → redirects to Official UI
      - INSPECTOR → redirects to PMU/Inspector UI
      - NGO_REPRESENTATIVE → redirects to NGO UI
    """
    if not payload.email or not payload.email.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Email address is required for role resolution.",
        )

    ensure_seed_whitelist(db)

    result = resolve_user_role_from_db_or_seed(
        email=payload.email,
        db=db,
        clerk_user_id=payload.clerk_user_id,
    )
    return result


@router.get("/whitelist", response_model=List[WhitelistResponse])
def get_whitelist(db: Session = Depends(get_db)):
    """Retrieve all configured email role whitelist entries."""
    ensure_seed_whitelist(db)
    return db.query(UserRoleWhitelist).order_by(UserRoleWhitelist.created_at.asc()).all()


@router.post("/whitelist", response_model=WhitelistResponse, status_code=status.HTTP_201_CREATED)
def add_or_update_whitelist(
    payload: WhitelistCreate,
    db: Session = Depends(get_db),
):
    """Admin endpoint to add or update an email's assigned role."""
    normalized_email = payload.email.strip().lower()
    valid_roles = {"OFFICIAL", "INSPECTOR", "NGO"}
    if payload.role.upper() not in valid_roles:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid role '{payload.role}'. Must be one of: {sorted(valid_roles)}",
        )

    existing = db.query(UserRoleWhitelist).filter(
        UserRoleWhitelist.email.ilike(normalized_email)
    ).first()

    if existing:
        existing.role = payload.role.upper()
        if payload.full_name is not None:
            existing.full_name = payload.full_name
        if payload.designation is not None:
            existing.designation = payload.designation
        existing.is_active = payload.is_active
        db.commit()
        db.refresh(existing)
        return existing
    else:
        new_entry = UserRoleWhitelist(
            email=normalized_email,
            role=payload.role.upper(),
            full_name=payload.full_name,
            designation=payload.designation,
            is_active=payload.is_active,
        )
        db.add(new_entry)
        db.commit()
        db.refresh(new_entry)
        return new_entry


@router.delete("/whitelist/{email}", status_code=status.HTTP_204_NO_CONTENT)
def delete_from_whitelist(email: str, db: Session = Depends(get_db)):
    """Delete an email from the whitelist."""
    normalized = email.strip().lower()
    entry = db.query(UserRoleWhitelist).filter(
        UserRoleWhitelist.email.ilike(normalized)
    ).first()
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Email '{email}' not found in whitelist",
        )
    db.delete(entry)
    db.commit()
    return None
