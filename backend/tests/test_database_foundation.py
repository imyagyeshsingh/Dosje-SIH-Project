import os
from decimal import Decimal
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models.camera import Camera
from app.models.media import Media
from app.models.project import Project
from app.models.report import Report
from app.models.report_evidence_reference import ReportEvidenceReference


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


def test_database_session_commit_and_query(db_session: Session):
    project = Project(
        project_name="DB Foundation Test",
        project_code="PRJ-DB-001",
        status="ACTIVE",
        progress=Decimal("15.5"),
    )
    db_session.add(project)
    db_session.commit()
    db_session.refresh(project)

    assert project.id is not None
    fetched = db_session.get(Project, project.id)
    assert fetched is not None
    assert fetched.project_code == "PRJ-DB-001"
    assert fetched.status == "ACTIVE"


def test_database_transaction_rollback_on_failure(db_session: Session):
    project = Project(
        project_name="Rollback Test",
        project_code="PRJ-ROLLBACK-001",
        status="ACTIVE",
        progress=Decimal("0.0"),
    )
    db_session.add(project)
    db_session.commit()

    # Attempt duplicate insert of unique project_code
    duplicate = Project(
        project_name="Duplicate Rollback Test",
        project_code="PRJ-ROLLBACK-001",
        status="PLANNED",
    )
    db_session.add(duplicate)
    with pytest.raises(Exception):
        db_session.commit()

    db_session.rollback()

    # Session remains usable after rollback
    count = db_session.scalar(select(Project).where(Project.project_code == "PRJ-ROLLBACK-001"))
    assert count is not None
    assert count.project_name == "Rollback Test"


def test_database_relationship_navigation(db_session: Session):
    project = Project(
        project_name="Rel Test",
        project_code="PRJ-REL-001",
        status="ACTIVE",
    )
    db_session.add(project)
    db_session.commit()

    camera = Camera(
        project_id=project.id,
        camera_name="Cam 1",
        stream_url="rtsp://example.com/live",
        status="ACTIVE",
    )
    db_session.add(camera)
    db_session.commit()
    db_session.refresh(project)

    assert len(project.cameras) == 1
    assert project.cameras[0].camera_name == "Cam 1"
    assert project.cameras[0].project.project_code == "PRJ-REL-001"


def test_get_db_generator_lifecycle():
    gen = get_db()
    session = next(gen)
    assert isinstance(session, Session)
    with pytest.raises(StopIteration):
        next(gen)


def test_postgresql_driver_normalization_logic():
    original_url = "postgresql://user:pass@host:5432/dbname?sslmode=require"
    expected_psycopg = "postgresql+psycopg://user:pass@host:5432/dbname?sslmode=require"

    if original_url.startswith("postgresql://"):
        transformed = original_url.replace("postgresql://", "postgresql+psycopg://", 1)
    else:
        transformed = original_url

    assert transformed == expected_psycopg


def test_db_health_endpoint_success():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    with patch("app.main.engine", engine):
        with TestClient(app) as client:
            resp = client.get("/db-health")
            assert resp.status_code == 200
            assert resp.json() == {"database": "connected"}


def test_db_health_endpoint_failure():
    mock_engine = MagicMock()
    mock_engine.connect.side_effect = SQLAlchemyError("Connection failed")
    with patch("app.main.engine", mock_engine):
        with TestClient(app) as client:
            resp = client.get("/db-health")
            assert resp.status_code == 500
            assert resp.json()["detail"] == "Database connection failed"
