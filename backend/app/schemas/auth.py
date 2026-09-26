from typing import List, Optional
from pydantic import BaseModel, ConfigDict, EmailStr, Field


class ResolveRoleRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    email: str = Field(..., description="Authenticated user email address")
    clerk_user_id: Optional[str] = Field(None, description="Clerk user ID if available")
    clerk_token: Optional[str] = Field(None, description="Clerk session token if available")


class ResolveRoleResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    email: str
    role: str  # "OFFICIAL", "INSPECTOR", "NGO_REPRESENTATIVE"
    user_id: str
    full_name: str
    designation: str
    permissions: List[str]
    ngo_registration_status: Optional[str] = "approved"
    organization_id: Optional[str] = None
    organization_name: Optional[str] = None
    authorized_project_ids: List[str] = []
    clerk_user_id: Optional[str] = None


class WhitelistCreate(BaseModel):
    email: str = Field(..., description="Email address to whitelist")
    role: str = Field(..., description="Assigned role: OFFICIAL, INSPECTOR, or NGO")
    full_name: Optional[str] = None
    designation: Optional[str] = None
    is_active: bool = True


class WhitelistResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    role: str
    full_name: Optional[str] = None
    designation: Optional[str] = None
    is_active: bool


class SendOtpRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    email: str = Field(..., description="Email address to receive OTP code")


class SendOtpResponse(BaseModel):
    success: bool = True
    message: str
    email: str
    expires_in: int = 300
    dev_otp: Optional[str] = None
    clerk_sent: Optional[bool] = False


class VerifyOtpRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    email: str = Field(..., description="Email address being verified")
    otp: str = Field(..., min_length=4, max_length=8, description="6-digit verification code")
    clerk_user_id: Optional[str] = None


class VerifyOtpResponse(BaseModel):
    success: bool = True
    message: str
    token: str
    user: ResolveRoleResponse
