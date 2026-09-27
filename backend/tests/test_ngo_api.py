import uuid
import pytest
from fastapi.testclient import TestClient

from app.database import Base, engine, get_db
from app.main import app
from app.models.ngo import NGO


@pytest.fixture
def client():
    return TestClient(app)


def test_new_ngo_registration_status(client):
    unique_email = f"ngo_{uuid.uuid4().hex[:8]}@example.com"
    response = client.get(
        "/api/v1/ngo/registration-status",
        headers={"X-User-Email": unique_email},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "incomplete"


def test_ngo_registration_flow_and_official_review(client):
    test_id = f"ngo_test_{uuid.uuid4().hex[:8]}"
    test_email = f"{test_id}@testngo.org"

    # 1. Submit registration
    payload = {
        "id": test_id,
        "fullName": "Smt. Sunita Rao",
        "designation": "General Secretary",
        "mobileNumber": "+91 9123456780",
        "email": test_email,
        "ngoName": "Lok Kalyan Sansthan",
        "organizationType": "Trust",
        "registrationNumber": f"TRU-{uuid.uuid4().hex[:6].upper()}",
        "establishmentYear": 2016,
        "contactNumber": "+91 522 2345678",
        "officialEmail": test_email,
        "address": "Civil Lines",
        "state": "Uttar Pradesh",
        "district": "Lucknow",
        "city": "Lucknow",
        "pinCode": "226001",
    }

    submit_resp = client.post(
        "/api/v1/ngo/registration/submit",
        json=payload,
        headers={"X-User-Email": test_email},
    )
    assert submit_resp.status_code == 200
    sub_data = submit_resp.json()
    assert sub_data["status"] == "submitted"
    assert sub_data["ngoName"] == "Lok Kalyan Sansthan"

    # 2. Official retrieves all NGOs - our submitted NGO must be present
    official_resp = client.get("/api/v1/official/ngos")
    assert official_resp.status_code == 200
    all_ngos = official_resp.json()
    matching = [n for n in all_ngos if n["id"] == test_id]
    assert len(matching) == 1
    assert matching[0]["status"] == "submitted"

    # 3. Check role resolution reflects 'submitted' status
    resolve_resp = client.post(
        "/api/v1/auth/resolve-role",
        json={"email": test_email},
    )
    assert resolve_resp.status_code == 200
    resolve_data = resolve_resp.json()
    assert resolve_data["role"] == "NGO_REPRESENTATIVE"
    assert resolve_data["ngo_registration_status"] == "submitted"

    # 4. Official requests correction
    correction_resp = client.post(
        f"/api/v1/official/ngos/{test_id}/correction",
        json={"notes": "Please provide updated PAN card and registration certificate."},
    )
    assert correction_resp.status_code == 200
    assert correction_resp.json()["status"] == "correctionRequired"

    # 5. Official approves registration
    approve_resp = client.post(
        f"/api/v1/official/ngos/{test_id}/approve",
        json={"notes": "All documents verified and approved."},
    )
    assert approve_resp.status_code == 200
    assert approve_resp.json()["status"] == "approved"

    # 6. Verify role resolution now reflects 'approved'
    resolve_resp2 = client.post(
        "/api/v1/auth/resolve-role",
        json={"email": test_email},
    )
    assert resolve_resp2.status_code == 200
    assert resolve_resp2.json()["ngo_registration_status"] == "approved"

    # Cleanup test record
    db = next(get_db())
    db.query(NGO).filter(NGO.id == test_id).delete()
    db.commit()
