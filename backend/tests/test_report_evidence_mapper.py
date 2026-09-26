"""
tests/test_report_evidence_mapper.py — Regression test for Report <-> ReportEvidenceReference mapper initialization.

Proves:
1. SQLAlchemy mappers initialize without InvalidRequestError when all models including
   Report and ReportEvidenceReference are imported.
2. Bidirectional relationship works:
   - Report.evidence_references contains ReportEvidenceReference instances.
   - ReportEvidenceReference.report references the parent Report.
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import configure_mappers, sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base
from app.models.ai_detection import AIDetection
from app.models.alert import Alert
from app.models.attendance import Attendance
from app.models.camera import Camera
from app.models.inspection import Inspection
from app.models.inspector import Inspector
from app.models.media import Media
from app.models.notification import Notification
from app.models.project import Project
from app.models.report import Report
from app.models.report_evidence_reference import ReportEvidenceReference
from app.models.video_session import VideoSession


def test_mapper_initializes_without_errors():
    """Verify that configure_mappers() succeeds when Report and ReportEvidenceReference are mapped."""
    configure_mappers()


def test_bidirectional_report_evidence_relationship():
    """Verify that Report and ReportEvidenceReference navigate bidirectionally."""
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSession = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    Base.metadata.create_all(bind=engine)

    with TestingSession() as db:
        project = Project(
            project_name="Mapper Test Project",
            project_code="MAP-001",
            status="ACTIVE",
            progress=10,
        )
        db.add(project)
        db.commit()
        db.refresh(project)

        inspection = Inspection(
            project_id=project.id,
            inspection_type="MANUAL",
            status="PENDING",
            assignment_status="UNASSIGNED",
        )
        db.add(inspection)
        db.commit()
        db.refresh(inspection)

        report = Report(
            project_id=project.id,
            inspection_id=inspection.id,
            report_type="INSPECTION",
            status="DRAFT",
            title="Mapper Verification Report",
        )
        db.add(report)
        db.commit()
        db.refresh(report)

        ref = ReportEvidenceReference(
            report_id=report.id,
            external_evidence_id="ev-12345",
            evidence_type="IMAGE",
            source="manual_test",
        )
        db.add(ref)
        db.commit()
        db.refresh(ref)
        db.refresh(report)

        # Forward relationship navigation
        assert len(report.evidence_references) == 1
        assert report.evidence_references[0].id == ref.id
        assert report.evidence_references[0].external_evidence_id == "ev-12345"

        # Reverse relationship navigation
        assert ref.report.id == report.id
        assert ref.report.title == "Mapper Verification Report"

    Base.metadata.drop_all(bind=engine)
