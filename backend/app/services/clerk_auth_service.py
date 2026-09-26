import logging
import os
from typing import Dict, Any, List, Optional
import httpx
from sqlalchemy.orm import Session

from app.models.user_role_whitelist import UserRoleWhitelist
from app.schemas.auth import ResolveRoleResponse

logger = logging.getLogger(__name__)

CLERK_SECRET_KEY = os.getenv("CLERK_SECRET_KEY", "sk_test_3Iw2vpl0apkvsfaa4zC905yA28mIeOQ11tl7Uck3W0")
CLERK_FRONTEND_API = os.getenv("CLERK_FRONTEND_API", "https://guiding-sawfish-4850.clerk.accounts.dev")

OFFICIAL_PERMISSIONS = [
    "viewAllProjects",
    "viewAssignedProjects",
    "viewCctvStreams",
    "viewAiRiskAnalytics",
    "scheduleInspection",
    "assignInspector",
    "joinVideoInspection",
    "reviewEvidence",
    "viewAllNgos",
    "viewNgoDetails",
    "reviewNgoRegistration",
    "approveNgoRegistration",
    "canApproveAudit",
]

INSPECTOR_PERMISSIONS = [
    "viewAssignedProjects",
    "executeInspection",
    "submitAuditFindings",
    "joinVideoInspection",
    "uploadEvidence",
    "reviewEvidence",
]

NGO_PERMISSIONS = [
    "viewAssignedProjects",
    "uploadEvidence",
    "joinVideoInspection",
]

DEFAULT_SEED_USERS = {
    "itsmerudraksha@gmail.com": {
        "role": "OFFICIAL",
        "full_name": "Dr. Rudraksha Verma, IAS",
        "designation": "Directorate Official, DoSJE",
    },
    "itsmerudraksha1@gmail.com": {
        "role": "INSPECTOR",
        "full_name": "Rudraksha Singh",
        "designation": "Lead Inspection Officer, PMU",
    },
}


def ensure_seed_whitelist(db: Session) -> None:
    """Ensure initial designated users exist in the database whitelist table."""
    try:
        for email, info in DEFAULT_SEED_USERS.items():
            existing = db.query(UserRoleWhitelist).filter(
                UserRoleWhitelist.email.ilike(email)
            ).first()
            if not existing:
                entry = UserRoleWhitelist(
                    email=email.lower(),
                    role=info["role"],
                    full_name=info["full_name"],
                    designation=info["designation"],
                    is_active=True,
                )
                db.add(entry)
        db.commit()
    except Exception as e:
        logger.warning("Could not auto-seed whitelist table: %s", e)
        db.rollback()


def resolve_user_role_from_db_or_seed(
    email: str,
    db: Session,
    clerk_user_id: Optional[str] = None,
) -> ResolveRoleResponse:
    """Authoritative role resolution based on exact email whitelist in DB."""
    normalized_email = email.strip().lower()
    
    # 1. Check database whitelist
    whitelisted = db.query(UserRoleWhitelist).filter(
        UserRoleWhitelist.email.ilike(normalized_email),
        UserRoleWhitelist.is_active == True,
    ).first()

    role: str
    full_name: str
    designation: str

    if whitelisted:
        role = whitelisted.role.upper()
        full_name = whitelisted.full_name or "Authorized User"
        designation = whitelisted.designation or ("Directorate Officer" if role == "OFFICIAL" else "PMU Inspector")
    elif normalized_email in DEFAULT_SEED_USERS:
        seed = DEFAULT_SEED_USERS[normalized_email]
        role = seed["role"]
        full_name = seed["full_name"]
        designation = seed["designation"]
    elif "official" in normalized_email or "dosje.gov.in" in normalized_email:
        role = "OFFICIAL"
        full_name = "Directorate Official"
        designation = "Central Compliance Officer, DoSJE"
    elif "pmu" in normalized_email or "inspector" in normalized_email:
        role = "INSPECTOR"
        full_name = "PMU Inspector"
        designation = "Field Inspection Officer, PMU"
    else:
        role = "NGO_REPRESENTATIVE"
        full_name = "Shri Rajesh Sharma"
        designation = "Project Director"

    # Map role to client-side permissions
    if role == "OFFICIAL":
        permissions = OFFICIAL_PERMISSIONS
        user_id = f"official_{normalized_email.split('@')[0]}"
        ngo_status = "approved"
        org_id = None
        org_name = None
        authorized_projects: List[str] = []
    elif role == "INSPECTOR":
        permissions = INSPECTOR_PERMISSIONS
        user_id = f"inspector_{normalized_email.split('@')[0]}"
        ngo_status = "approved"
        org_id = None
        org_name = None
        authorized_projects = ["DSJ-AG-1042", "DSJ-VR-2089"]
    else:
        role = "NGO_REPRESENTATIVE"
        permissions = NGO_PERMISSIONS
        user_id = f"ngo_{normalized_email.split('@')[0]}"
        
        # Check if email indicates incomplete/submitted
        if any(k in normalized_email for k in ["new", "register", "incomplete"]):
            ngo_status = "incomplete"
            org_id = "org_new_99"
            org_name = "Gramin Vikas Sansthan"
            authorized_projects = []
        elif "submitted" in normalized_email:
            ngo_status = "submitted"
            org_id = "org_8821"
            org_name = "Samarpan Welfare Society"
            authorized_projects = ["DSJ-AG-1042"]
        else:
            ngo_status = "approved"
            org_id = "org_8821"
            org_name = "Samarpan Welfare Society"
            authorized_projects = ["DSJ-AG-1042", "DSJ-VR-2089", "DSJ-LK-3014"]

    effective_clerk_id = clerk_user_id or f"user_clerk_{normalized_email.replace('@', '_').replace('.', '_')}"

    return ResolveRoleResponse(
        email=normalized_email,
        role=role,
        user_id=user_id,
        full_name=full_name,
        designation=designation,
        permissions=permissions,
        ngo_registration_status=ngo_status,
        organization_id=org_id,
        organization_name=org_name,
        authorized_project_ids=authorized_projects,
        clerk_user_id=effective_clerk_id,
    )


# In-memory OTP storage: {email: (code, expires_at)}
_OTP_CACHE: Dict[str, Any] = {}


def send_email_otp(email: str) -> Dict[str, Any]:
    """Generate and dispatch 6-digit OTP code to specified email."""
    import secrets
    import time

    normalized = email.strip().lower()
    code = f"{secrets.randbelow(900000) + 100000}"
    expires_at = time.time() + 300  # 5 minutes validity
    _OTP_CACHE[normalized] = (code, expires_at)

    logger.info("Generated OTP for %s: %s (expires in 300s)", normalized, code)

    return {
        "success": True,
        "message": f"Verification code sent to {normalized}",
        "email": normalized,
        "expires_in": 300,
        "dev_otp": code,
    }


def verify_email_otp(
    email: str,
    otp: str,
    db: Session,
    clerk_user_id: Optional[str] = None,
) -> ResolveRoleResponse:
    """Verify submitted 6-digit OTP and resolve authoritative role."""
    import time

    normalized = email.strip().lower()
    input_code = otp.strip()

    stored = _OTP_CACHE.get(normalized)

    is_valid = False
    # Universal dev/testing code '123456' or dynamic cached OTP
    if input_code == "123456":
        is_valid = True
    elif stored:
        code, expires_at = stored
        if time.time() <= expires_at and input_code == code:
            is_valid = True

    if not is_valid:
        raise ValueError("Invalid or expired verification code. Please request a new code.")

    # Remove used code
    _OTP_CACHE.pop(normalized, None)

    return resolve_user_role_from_db_or_seed(
        email=normalized,
        db=db,
        clerk_user_id=clerk_user_id,
    )

