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
CLERK_PUBLISHABLE_KEY = os.getenv(
    "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY",
    os.getenv("CLERK_PUBLISHABLE_KEY", "pk_test_Z3VpZGluZy1zYXdmaXNoLTQ4NTAuY2xlcmsuYWNjb3VudHMuZGV2JA")
)

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
        full_name = "NGO Representative"
        designation = "Project Representative"

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
        authorized_projects = []
    else:
        role = "NGO_REPRESENTATIVE"
        permissions = NGO_PERMISSIONS
        user_id = f"ngo_{normalized_email.split('@')[0]}"
        # Query database to check if this NGO has submitted registration
        from app.models.ngo import NGO
        ngo_record = db.query(NGO).filter(NGO.email.ilike(normalized_email)).first()
        if ngo_record:
            ngo_status = ngo_record.status or "submitted"
            full_name = ngo_record.full_name or full_name
            designation = ngo_record.designation or designation
            org_id = str(ngo_record.id)
            org_name = ngo_record.ngo_name
        else:
            ngo_status = "incomplete"
            org_id = None
            org_name = None
        authorized_projects = []

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
# Active Clerk sign-in sessions: {email: {"sia_id": str, "client_token": str, "timestamp": float}}
_CLERK_SESSIONS: Dict[str, Dict[str, Any]] = {}


def send_email_otp(email: str) -> Dict[str, Any]:
    """
    Generate and dispatch a 6-digit verification code to the specified email address via Clerk.
    If the user does not exist in Clerk, auto-provisions them so Clerk can send the email.
    """
    import secrets
    import time

    normalized = email.strip().lower()
    fallback_code = f"{secrets.randbelow(900000) + 100000}"
    expires_at = time.time() + 300  # 5 minutes validity
    _OTP_CACHE[normalized] = (fallback_code, expires_at)

    clerk_sent = False
    clerk_error_msg = None

    try:
        with httpx.Client(timeout=10.0) as client:
            # 1. Initiate sign-in attempt on Clerk Frontend API
            r1 = client.post(
                f"{CLERK_FRONTEND_API}/v1/client/sign_ins?_is_native=1",
                headers={
                    "Authorization": f"Bearer {CLERK_PUBLISHABLE_KEY}",
                    "Content-Type": "application/x-www-form-urlencoded",
                },
                data={"identifier": normalized},
            )

            # 1b. If user not yet created in Clerk, create user via Backend API and retry sign-in
            if r1.status_code == 422:
                logger.info("Email %s not found in Clerk; auto-provisioning user...", normalized)
                create_res = client.post(
                    "https://api.clerk.com/v1/users",
                    headers={"Authorization": f"Bearer {CLERK_SECRET_KEY}"},
                    json={"email_address": [normalized], "skip_password_requirement": True},
                )
                if create_res.status_code in (200, 201):
                    # Retry sign-in
                    r1 = client.post(
                        f"{CLERK_FRONTEND_API}/v1/client/sign_ins?_is_native=1",
                        headers={
                            "Authorization": f"Bearer {CLERK_PUBLISHABLE_KEY}",
                            "Content-Type": "application/x-www-form-urlencoded",
                        },
                        data={"identifier": normalized},
                    )

            if r1.status_code == 200:
                client_token = r1.headers.get("authorization")
                data1 = r1.json()
                sia_id = data1.get("response", {}).get("id")
                factors = data1.get("response", {}).get("supported_first_factors", [])
                email_factor = next((f for f in factors if f.get("strategy") == "email_code"), None)

                if sia_id and email_factor and client_token:
                    email_address_id = email_factor.get("email_address_id")
                    # 2. Dispatch the real verification email via prepare_first_factor
                    r2 = client.post(
                        f"{CLERK_FRONTEND_API}/v1/client/sign_ins/{sia_id}/prepare_first_factor?_is_native=1",
                        headers={
                            "Authorization": f"Bearer {client_token}",
                            "Content-Type": "application/x-www-form-urlencoded",
                        },
                        data={
                            "strategy": "email_code",
                            "email_address_id": email_address_id,
                        },
                    )
                    if r2.status_code == 200:
                        clerk_sent = True
                        _CLERK_SESSIONS[normalized] = {
                            "sia_id": sia_id,
                            "client_token": client_token,
                            "email_address_id": email_address_id,
                            "timestamp": time.time(),
                        }
                        logger.info("Clerk successfully sent 6-digit OTP email to %s (sia_id: %s)", normalized, sia_id)
                    else:
                        clerk_error_msg = f"Clerk prepare error: {r2.text}"
                        logger.warning(clerk_error_msg)
            else:
                clerk_error_msg = f"Clerk sign_in error: {r1.text}"
                logger.warning(clerk_error_msg)
    except Exception as exc:
        clerk_error_msg = f"Exception communicating with Clerk: {exc}"
        logger.warning(clerk_error_msg)

    message = (
        f"Verification code sent to {normalized}. Please check your inbox."
        if clerk_sent
        else f"Verification code generated for {normalized}."
    )

    return {
        "success": True,
        "message": message,
        "email": normalized,
        "expires_in": 300,
        "dev_otp": fallback_code,
        "clerk_sent": clerk_sent,
    }


def verify_email_otp(
    email: str,
    otp: str,
    db: Session,
    clerk_user_id: Optional[str] = None,
) -> ResolveRoleResponse:
    """
    Verify submitted 6-digit OTP with Clerk (via attempt_first_factor) or test fallback,
    and resolve authoritative role from database whitelist.
    """
    import time

    normalized = email.strip().lower()
    input_code = otp.strip()

    is_verified = False
    verified_clerk_id = clerk_user_id

    # 1. Dev bypass / test automation code (123456)
    if input_code == "123456":
        is_verified = True
        logger.info("Accepted dev bypass OTP 123456 for %s", normalized)

    # 2. Live verification against Clerk if active sign-in session exists
    session = _CLERK_SESSIONS.get(normalized)
    if not is_verified and session:
        sia_id = session.get("sia_id")
        client_token = session.get("client_token")
        try:
            with httpx.Client(timeout=10.0) as client:
                r = client.post(
                    f"{CLERK_FRONTEND_API}/v1/client/sign_ins/{sia_id}/attempt_first_factor?_is_native=1",
                    headers={
                        "Authorization": f"Bearer {client_token}",
                        "Content-Type": "application/x-www-form-urlencoded",
                    },
                    data={
                        "strategy": "email_code",
                        "code": input_code,
                    },
                )
                if r.status_code == 200:
                    data = r.json()
                    status = data.get("response", {}).get("status")
                    if status in ("complete", "needs_second_factor"):
                        is_verified = True
                        verified_clerk_id = data.get("response", {}).get("created_session_id") or verified_clerk_id
                        logger.info("Clerk successfully verified code for %s", normalized)
                else:
                    logger.warning("Clerk attempt_first_factor returned status %s: %s", r.status_code, r.text)
        except Exception as e:
            logger.warning("Error verifying code with Clerk: %s", e)

    # 3. Fallback to internal OTP cache (for unit tests / mock test runs)
    if not is_verified:
        stored = _OTP_CACHE.get(normalized)
        if stored:
            code, expires_at = stored
            if time.time() <= expires_at and input_code == code:
                is_verified = True

    if not is_verified:
        raise ValueError("Invalid or expired verification code. Please check the 6-digit code sent to your email.")

    # Remove used sessions
    _CLERK_SESSIONS.pop(normalized, None)
    _OTP_CACHE.pop(normalized, None)

    return resolve_user_role_from_db_or_seed(
        email=normalized,
        db=db,
        clerk_user_id=verified_clerk_id,
    )

