import logging
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.models.inspector import Inspector
from app.models.project import Project

logger = logging.getLogger(__name__)

OFFICIAL_SEED_PROJECTS = [
    {
        "project_name": "District Rehabilitation & Support Centre",
        "project_code": "DSJ-AG-1042",
        "department": "Disability Welfare & Skill Training",
        "location": "Plot 14, Sanjay Place, Agra, Uttar Pradesh - 282002",
        "progress": 68.00,
        "status": "ACTIVE",
        "description": "Comprehensive physical rehabilitation, assistive device distribution, and vocational skill development facility under DoSJE.",
    },
    {
        "project_name": "Integrated Child Development & Daycare Centre",
        "project_code": "DSJ-VR-2089",
        "department": "Child Welfare & Social Care",
        "location": "Plot 8B, Sigra, Varanasi, Uttar Pradesh - 221002",
        "progress": 82.50,
        "status": "ACTIVE",
        "description": "Specialized nutrition, healthcare, and educational support center for children under vulnerable socio-economic demographics.",
    },
    {
        "project_name": "Senior Citizens Assisted Living Home",
        "project_code": "DSJ-LK-3014",
        "department": "Geriatric Support Services",
        "location": "Sector 5, Gomti Nagar, Lucknow, Uttar Pradesh - 226010",
        "progress": 45.00,
        "status": "ACTIVE",
        "description": "Residential geriatric healthcare and community center for senior citizens under Atal Vayo Abhyuday Yojana (AVYAY).",
    },
    {
        "project_name": "Stark Educational & Child Care Center",
        "project_code": "DSJ-MN-4011",
        "department": "Educational & Child Care",
        "location": "Agra Road, Mainpuri, Uttar Pradesh - 205001",
        "progress": 35.00,
        "status": "ACTIVE",
        "description": "Non-governmental educational outreach, nutritious meal distribution, and primary care shelter run by Stark Organization.",
    },
    {
        "project_name": "National Divyangjan Skill & Vocational Centre",
        "project_code": "DSJ-ND-5022",
        "department": "Skill Development & Livelihood",
        "location": "Sector 62, Noida, Uttar Pradesh - 201301",
        "progress": 90.00,
        "status": "ACTIVE",
        "description": "Advanced adaptive computer training and accessible vocational technology workshops for Divyangjan youth.",
    },
]

OFFICIAL_SEED_INSPECTORS = [
    {
        "inspector_id": "INS-PMU-001",
        "inspector_name": "Shri V. K. Saxena (Joint Director / Squad Lead)",
        "is_active": True,
    },
    {
        "inspector_id": "INS-PMU-002",
        "inspector_name": "Rudraksha Singh (Lead Inspection Officer, PMU)",
        "is_active": True,
    },
    {
        "inspector_id": "INS-PMU-003",
        "inspector_name": "Khushboo Rathore (Senior Enforcement Officer, PMU)",
        "is_active": True,
    },
    {
        "inspector_id": "INS-PMU-004",
        "inspector_name": "Smt. Sunita Sharma (Vigilance & Audit Officer)",
        "is_active": True,
    },
    {
        "inspector_id": "PMU-SQD-01",
        "inspector_name": "Central PMU Flying Squad Alpha (Surprise Audit Team)",
        "is_active": True,
    },
    {
        "inspector_id": "PMU-SQD-02",
        "inspector_name": "State Welfare Enforcement Squad Beta",
        "is_active": True,
    },
]


def ensure_seed_projects_and_inspectors(db: Session) -> None:
    """Ensure authentic DoSJE projects and PMU squads exist in the database."""
    try:
        # 1. Projects
        for pdata in OFFICIAL_SEED_PROJECTS:
            code = pdata["project_code"]
            existing = db.scalar(select(Project).where(Project.project_code == code).limit(1))
            if existing is None:
                new_proj = Project(
                    project_name=pdata["project_name"],
                    project_code=code,
                    department=pdata["department"],
                    location=pdata["location"],
                    progress=pdata["progress"],
                    status=pdata["status"],
                    description=pdata["description"],
                )
                db.add(new_proj)
            else:
                # Update to official details if it had placeholder/test name
                if "Test Integration" in existing.project_name or existing.project_name != pdata["project_name"]:
                    existing.project_name = pdata["project_name"]
                    existing.department = pdata["department"]
                    existing.location = pdata["location"]
                    existing.description = pdata["description"]
                    existing.progress = pdata["progress"]
                    existing.status = pdata["status"]

        # 2. Inspectors
        for idata in OFFICIAL_SEED_INSPECTORS:
            insp_id = idata["inspector_id"]
            existing_insp = db.scalar(select(Inspector).where(Inspector.inspector_id == insp_id).limit(1))
            if existing_insp is None:
                new_insp = Inspector(
                    inspector_id=insp_id,
                    inspector_name=idata["inspector_name"],
                    is_active=idata["is_active"],
                )
                db.add(new_insp)
            else:
                if existing_insp.inspector_name != idata["inspector_name"]:
                    existing_insp.inspector_name = idata["inspector_name"]
                    existing_insp.is_active = idata["is_active"]

        db.commit()
    except Exception as e:
        db.rollback()
        logger.warning("Could not auto-seed projects and inspectors: %s", e)
