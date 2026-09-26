import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app

SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(autouse=True)
def setup_database():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client():
    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def test_resolve_role_official(client: TestClient):
    """Verify itsmerudraksha@gmail.com resolves to OFFICIAL role."""
    response = client.post(
        "/api/v1/auth/resolve-role",
        json={"email": "itsmerudraksha@gmail.com"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == "itsmerudraksha@gmail.com"
    assert data["role"] == "OFFICIAL"
    assert "viewAllProjects" in data["permissions"]
    assert "canApproveAudit" in data["permissions"]
    assert "scheduleInspection" in data["permissions"]


def test_resolve_role_inspector_pmu(client: TestClient):
    """Verify itsmerudraksha1@gmail.com resolves to INSPECTOR role."""
    response = client.post(
        "/api/v1/auth/resolve-role",
        json={"email": "itsmerudraksha1@gmail.com"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == "itsmerudraksha1@gmail.com"
    assert data["role"] == "INSPECTOR"
    assert "executeInspection" in data["permissions"]
    assert "submitAuditFindings" in data["permissions"]
    assert "canApproveAudit" not in data["permissions"]


def test_resolve_role_ngo_default(client: TestClient):
    """Verify non-whitelisted email resolves to NGO_REPRESENTATIVE."""
    response = client.post(
        "/api/v1/auth/resolve-role",
        json={"email": "samarpan.welfare@ngo-india.org"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == "samarpan.welfare@ngo-india.org"
    assert data["role"] == "NGO_REPRESENTATIVE"
    assert "uploadEvidence" in data["permissions"]
    assert "executeInspection" not in data["permissions"]


def test_resolve_role_empty_email_validation(client: TestClient):
    """Verify empty email returns 422 validation error."""
    response = client.post(
        "/api/v1/auth/resolve-role",
        json={"email": ""},
    )
    assert response.status_code == 422


def test_whitelist_crud_and_role_override(client: TestClient):
    """Verify adding an email to whitelist changes its resolved role."""
    test_email = "new.officer@domain.com"

    # Initially not whitelisted -> NGO
    res1 = client.post("/api/v1/auth/resolve-role", json={"email": test_email})
    assert res1.status_code == 200
    assert res1.json()["role"] == "NGO_REPRESENTATIVE"

    # Add to whitelist as OFFICIAL
    create_res = client.post(
        "/api/v1/auth/whitelist",
        json={
            "email": test_email,
            "role": "OFFICIAL",
            "full_name": "Shri New Officer",
            "designation": "Deputy Secretary",
        },
    )
    assert create_res.status_code == 201
    assert create_res.json()["role"] == "OFFICIAL"

    # Now resolves as OFFICIAL
    res2 = client.post("/api/v1/auth/resolve-role", json={"email": test_email})
    assert res2.status_code == 200
    assert res2.json()["role"] == "OFFICIAL"
    assert res2.json()["full_name"] == "Shri New Officer"


def test_whitelist_get_all(client: TestClient):
    """Verify GET /api/v1/auth/whitelist returns seeded users."""
    response = client.get("/api/v1/auth/whitelist")
    assert response.status_code == 200
    data = response.json()
    emails = [item["email"] for item in data]
    assert "itsmerudraksha@gmail.com" in emails
    assert "itsmerudraksha1@gmail.com" in emails
