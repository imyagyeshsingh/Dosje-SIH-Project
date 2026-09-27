from typing import Optional
from pydantic import BaseModel, ConfigDict, Field


class NgoProfilePayload(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: Optional[str] = None
    full_name: Optional[str] = Field(None, alias="fullName")
    designation: Optional[str] = None
    mobile_number: Optional[str] = Field(None, alias="mobileNumber")
    email: Optional[str] = None
    ngo_name: Optional[str] = Field(None, alias="ngoName")
    organization_type: Optional[str] = Field(None, alias="organizationType")
    registration_number: Optional[str] = Field(None, alias="registrationNumber")
    establishment_year: Optional[int] = Field(2020, alias="establishmentYear")
    contact_number: Optional[str] = Field(None, alias="contactNumber")
    official_email: Optional[str] = Field(None, alias="officialEmail")
    address: Optional[str] = None
    state: Optional[str] = None
    district: Optional[str] = None
    city: Optional[str] = None
    pin_code: Optional[str] = Field(None, alias="pinCode")
    status: Optional[str] = "submitted"


class NgoCorrectionPayload(BaseModel):
    notes: str


class NgoApprovePayload(BaseModel):
    notes: Optional[str] = "Approved by State Reviewing Authority."
