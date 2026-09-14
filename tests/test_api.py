import pytest
import io
import cv2
import numpy as np
from fastapi.testclient import TestClient
from main import app


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"


def test_athlete_lifecycle(client):
    import uuid
    code = f"INA-{uuid.uuid4().hex[:6]}"
    # 1. Create athlete
    payload = {"name": "Arjuna Srikandi", "athlete_code": code}
    resp = client.post("/api/athletes", json=payload)
    assert resp.status_code == 201
    created = resp.json()
    assert created["id"] > 0
    assert created["name"] == "Arjuna Srikandi"
    assert created["athlete_code"] == code
    athlete_id = created["id"]

    # Duplicate code rejection
    dup_resp = client.post("/api/athletes", json=payload)
    assert dup_resp.status_code == 400
    assert "already exists" in dup_resp.json()["detail"].lower()

    # 2. Get athlete
    get_resp = client.get(f"/api/athletes/{athlete_id}")
    assert get_resp.status_code == 200
    assert get_resp.json()["id"] == athlete_id

    # 3. List athletes
    list_resp = client.get("/api/athletes")
    assert list_resp.status_code == 200
    athletes = list_resp.json()
    assert any(a["id"] == athlete_id for a in athletes)


def test_session_bow_categories_and_validation(client):
    # Create athlete first
    ath_resp = client.post("/api/athletes", json={"name": "Diana Prince"})
    athlete_id = ath_resp.json()["id"]

    categories = ["Recurve", "Compound", "Barebow", "Standard Bow / National"]
    for cat in categories:
        s_resp = client.post(
            "/api/sessions",
            json={
                "athlete_id": athlete_id,
                "bow_category": cat,
                "session_type": "training",
                "distance": "70m",
                "arrows_per_end": 6,
                "total_ends": 10,
            },
        )
        assert s_resp.status_code == 201
        session = s_resp.json()
        assert session["bow_category"] == cat

    # Validation: Invalid bow category
    inv_resp = client.post(
        "/api/sessions",
        json={
            "athlete_id": athlete_id,
            "bow_category": "Crossbow",
            "distance": "70m",
            "arrows_per_end": 6,
            "total_ends": 10,
        },
    )
    assert inv_resp.status_code == 422

    # Validation: Non-existent athlete
    inv_ath = client.post(
        "/api/sessions",
        json={
            "athlete_id": 999999,
            "bow_category": "Recurve",
            "distance": "70m",
            "arrows_per_end": 6,
            "total_ends": 10,
        },
    )
    assert inv_ath.status_code == 404


def test_scoring_workflow_end_and_summary(client):
    # 1. Setup athlete and session
    ath = client.post("/api/athletes", json={"name": "Robin Hood"}).json()
    sess = client.post(
        "/api/sessions",
        json={
            "athlete_id": ath["id"],
            "bow_category": "Recurve",
            "session_type": "competition",
            "distance": "70m",
            "arrows_per_end": 6,
            "total_ends": 2,
        },
    ).json()
    session_id = sess["id"]

    # 2. Record End 1: 10X, 10, 9, 8, 7, M
    end1_payload = {
        "end_number": 1,
        "arrows": [
            {"arrow_number": 1, "score": "10X", "is_x": True},
            {"arrow_number": 2, "score": 10, "is_x": False},
            {"arrow_number": 3, "score": 9},
            {"arrow_number": 4, "score": 8},
            {"arrow_number": 5, "score": 7},
            {"arrow_number": 6, "score": "M"},
        ],
    }
    end1_resp = client.post(f"/api/sessions/{session_id}/ends", json=end1_payload)
    assert end1_resp.status_code == 201
    end1 = end1_resp.json()
    assert end1["total_score"] == 44
    assert end1["x_count"] == 1
    assert len(end1["arrows"]) == 6

    # 3. Check session score summary
    score_resp = client.get(f"/api/sessions/{session_id}/score")
    assert score_resp.status_code == 200
    summary = score_resp.json()
    assert summary["total_score"] == 44
    assert summary["total_x"] == 1
    assert summary["total_arrows"] == 6

    # 4. Edit End 1: change arrow 6 from M to 9 -> total becomes 53
    update_payload = {
        "arrows": [
            {"arrow_number": 1, "score": "10X", "is_x": True},
            {"arrow_number": 2, "score": 10, "is_x": False},
            {"arrow_number": 3, "score": 9},
            {"arrow_number": 4, "score": 8},
            {"arrow_number": 5, "score": 7},
            {"arrow_number": 6, "score": 9},
        ],
    }
    update_resp = client.put(f"/api/sessions/{session_id}/ends/1", json=update_payload)
    assert update_resp.status_code == 200
    updated_end1 = update_resp.json()
    assert updated_end1["total_score"] == 53
    assert updated_end1["x_count"] == 1

    # 5. Record End 2: 10, 10, 10, 9, 9, 8 = 56
    end2_payload = {
        "end_number": 2,
        "arrows": [
            {"arrow_number": 1, "score": 10},
            {"arrow_number": 2, "score": 10},
            {"arrow_number": 3, "score": 10},
            {"arrow_number": 4, "score": 9},
            {"arrow_number": 5, "score": 9},
            {"arrow_number": 6, "score": 8},
        ],
    }
    end2_resp = client.post(f"/api/sessions/{session_id}/ends", json=end2_payload)
    assert end2_resp.status_code == 201

    # 6. Check final session details
    details_resp = client.get(f"/api/sessions/{session_id}")
    assert details_resp.status_code == 200
    details = details_resp.json()
    assert details["session"]["status"] == "completed"  # All ends recorded
    assert details["summary"]["total_score"] == 53 + 56  # 109
    assert details["summary"]["total_arrows"] == 12
    assert details["summary"]["highest_scoring_end"]["score"] == 56
    assert details["summary"]["lowest_scoring_end"]["score"] == 53

    # 7. Verification: Cannot edit ends after session is completed
    cannot_edit = client.put(f"/api/sessions/{session_id}/ends/1", json=update_payload)
    assert cannot_edit.status_code == 400
    assert "completed session" in cannot_edit.json()["detail"].lower()


def test_ai_target_detection_flow(client):
    # Create test image with concentric rings and a yellow center
    img = np.ones((400, 400, 3), dtype=np.uint8) * 255
    # Outer black ring
    cv2.circle(img, (200, 200), 180, (50, 50, 50), -1)
    # Blue ring
    cv2.circle(img, (200, 200), 120, (230, 100, 50), -1)
    # Red ring
    cv2.circle(img, (200, 200), 80, (50, 50, 230), -1)
    # Yellow gold center
    cv2.circle(img, (200, 200), 40, (30, 215, 255), -1)

    _, encoded = cv2.imencode(".jpeg", img)
    image_bytes = encoded.tobytes()

    # Create session
    ath = client.post("/api/athletes", json={"name": "Katniss Everdeen"}).json()
    sess = client.post(
        "/api/sessions",
        json={
            "athlete_id": ath["id"],
            "bow_category": "Barebow",
            "distance": "18m",
            "arrows_per_end": 3,
            "total_ends": 5,
        },
    ).json()

    resp = client.post(
        f"/api/sessions/{sess['id']}/detect",
        files={"file": ("target.jpeg", io.BytesIO(image_bytes), "image/jpeg")},
    )
    assert resp.status_code == 200
    result = resp.json()
    assert result["target"]["detected"] is True
    for arrow in result["detected_arrows"]:
        assert arrow["arrow_number"] in [1, 2, 3]
        assert arrow["source"] == "ai"


def test_validation_edge_cases(client):
    ath = client.post("/api/athletes", json={"name": "Hawkeye"}).json()
    sess = client.post(
        "/api/sessions",
        json={
            "athlete_id": ath["id"],
            "bow_category": "Compound",
            "distance": "50m",
            "arrows_per_end": 3,
            "total_ends": 2,
        },
    ).json()
    sess_id = sess["id"]

    # 1. Reject too many arrows (4 arrows when max is 3)
    resp_too_many = client.post(
        f"/api/sessions/{sess_id}/ends",
        json={
            "end_number": 1,
            "arrows": [
                {"arrow_number": 1, "score": 10},
                {"arrow_number": 2, "score": 9},
                {"arrow_number": 3, "score": 8},
                {"arrow_number": 4, "score": 7},
            ],
        },
    )
    assert resp_too_many.status_code == 400
    assert "maximum allowed" in resp_too_many.json()["detail"].lower()

    # 2. Reject duplicate arrow numbers
    resp_dup = client.post(
        f"/api/sessions/{sess_id}/ends",
        json={
            "end_number": 1,
            "arrows": [
                {"arrow_number": 1, "score": 10},
                {"arrow_number": 1, "score": 9},
            ],
        },
    )
    assert resp_dup.status_code == 422  # Caught by Pydantic validator
    assert "duplicate" in resp_dup.text.lower()

    # 3. Reject end number beyond total_ends (end 3 when total is 2)
    resp_bad_end = client.post(
        f"/api/sessions/{sess_id}/ends",
        json={
            "end_number": 3,
            "arrows": [
                {"arrow_number": 1, "score": 10},
            ],
        },
    )
    assert resp_bad_end.status_code == 400
    assert "out of range" in resp_bad_end.json()["detail"].lower()

