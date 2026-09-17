import pytest
import io
import uuid
import cv2
import numpy as np
from fastapi.testclient import TestClient
from main import app


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c


# ==========================================
# 1. APPLICATION & STATIC CONTENT VERIFICATION
# ==========================================
class TestStaticAndHealthEndpoints:
    def test_health_check_returns_ok(self, client):
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data.get("status") == "ok"
        assert "Archery" in data.get("app", "")

    def test_root_and_app_routes_serve_html(self, client):
        for path in ["/", "/app"]:
            response = client.get(path)
            assert response.status_code == 200
            assert "text/html" in response.headers.get("content-type", "")
            assert "<!DOCTYPE html>" in response.text
            assert "Archery Score Pro" in response.text


# ==========================================
# 2. ATHLETE BLACK BOX TESTING
# ==========================================
class TestAthleteBlackBox:
    def test_create_athlete_success(self, client):
        unique_code = f"ATH-{uuid.uuid4().hex[:6].upper()}"
        payload = {
            "name": "Srikandi Wira",
            "athlete_code": unique_code,
        }
        res = client.post("/api/athletes", json=payload)
        assert res.status_code == 201
        data = res.json()
        assert data["id"] > 0
        assert data["name"] == "Srikandi Wira"
        assert data["athlete_code"] == unique_code

    def test_create_athlete_without_code(self, client):
        payload = {"name": "Anonymous Archer"}
        res = client.post("/api/athletes", json=payload)
        assert res.status_code == 201
        data = res.json()
        assert data["id"] > 0
        assert data["name"] == "Anonymous Archer"
        assert data.get("athlete_code") is None

    def test_create_athlete_duplicate_code_rejected(self, client):
        dup_code = f"DUP-{uuid.uuid4().hex[:6].upper()}"
        payload = {"name": "First Archer", "athlete_code": dup_code}
        res1 = client.post("/api/athletes", json=payload)
        assert res1.status_code == 201

        # Duplicate attempt
        res2 = client.post("/api/athletes", json={"name": "Second Archer", "athlete_code": dup_code})
        assert res2.status_code == 400
        assert "already exists" in res2.json()["detail"].lower()

    def test_create_athlete_invalid_payload(self, client):
        # Missing required 'name'
        res = client.post("/api/athletes", json={})
        assert res.status_code == 422

    def test_get_athlete_by_id_and_not_found(self, client):
        # Create
        ath = client.post("/api/athletes", json={"name": "Findable Archer"}).json()
        ath_id = ath["id"]

        # Valid ID
        res = client.get(f"/api/athletes/{ath_id}")
        assert res.status_code == 200
        assert res.json()["name"] == "Findable Archer"

        # Non-existent ID
        res_nf = client.get("/api/athletes/99999999")
        assert res_nf.status_code == 404
        assert "not found" in res_nf.json()["detail"].lower()

    def test_list_athletes(self, client):
        res = client.get("/api/athletes")
        assert res.status_code == 200
        athletes = res.json()
        assert isinstance(athletes, list)
        assert len(athletes) >= 1


# ==========================================
# 3. SESSION LIFECYCLE & BOUNDARY TESTING
# ==========================================
class TestSessionBlackBox:
    @pytest.fixture
    def test_athlete(self, client):
        res = client.post("/api/athletes", json={"name": f"Archer-{uuid.uuid4().hex[:4]}"})
        return res.json()

    def test_all_bow_categories_valid(self, client, test_athlete):
        valid_categories = ["Recurve", "Compound", "Barebow", "Standard Bow / National"]
        for cat in valid_categories:
            res = client.post(
                "/api/sessions",
                json={
                    "athlete_id": test_athlete["id"],
                    "bow_category": cat,
                    "session_type": "training",
                    "distance": "70m",
                    "arrows_per_end": 6,
                    "total_ends": 5,
                },
            )
            assert res.status_code == 201
            data = res.json()
            assert data["bow_category"] == cat
            assert data["status"] == "in_progress"

    def test_invalid_bow_category_rejected(self, client, test_athlete):
        res = client.post(
            "/api/sessions",
            json={
                "athlete_id": test_athlete["id"],
                "bow_category": "Longbow",  # Not in allowed enum
                "session_type": "training",
                "distance": "70m",
                "arrows_per_end": 6,
                "total_ends": 5,
            },
        )
        assert res.status_code == 422

    def test_session_boundary_arrow_and_end_counts(self, client, test_athlete):
        # Arrows per end: 3 and 6 (valid within 1-12)
        res_3 = client.post(
            "/api/sessions",
            json={
                "athlete_id": test_athlete["id"],
                "bow_category": "Recurve",
                "session_type": "training",
                "distance": "18m",
                "arrows_per_end": 3,
                "total_ends": 1,
            },
        )
        assert res_3.status_code == 201
        assert res_3.json()["arrows_per_end"] == 3

        # Arrows per end: boundary violation (e.g. 0 or 13 exceeds ge=1, le=12)
        res_invalid_arrows_low = client.post(
            "/api/sessions",
            json={
                "athlete_id": test_athlete["id"],
                "bow_category": "Recurve",
                "session_type": "training",
                "distance": "18m",
                "arrows_per_end": 0,
                "total_ends": 1,
            },
        )
        assert res_invalid_arrows_low.status_code == 422

        res_invalid_arrows_high = client.post(
            "/api/sessions",
            json={
                "athlete_id": test_athlete["id"],
                "bow_category": "Recurve",
                "session_type": "training",
                "distance": "18m",
                "arrows_per_end": 13,
                "total_ends": 1,
            },
        )
        assert res_invalid_arrows_high.status_code == 422

        # Total ends: 0 (invalid, must be >= 1)
        res_zero_ends = client.post(
            "/api/sessions",
            json={
                "athlete_id": test_athlete["id"],
                "bow_category": "Recurve",
                "session_type": "training",
                "distance": "18m",
                "arrows_per_end": 3,
                "total_ends": 0,
            },
        )
        assert res_zero_ends.status_code == 422

    def test_session_filtering_by_status_and_athlete(self, client, test_athlete):
        # Create session for this athlete
        client.post(
            "/api/sessions",
            json={
                "athlete_id": test_athlete["id"],
                "bow_category": "Barebow",
                "session_type": "training",
                "distance": "30m",
                "arrows_per_end": 3,
                "total_ends": 3,
            },
        ).json()

        # Filter by athlete_id
        res_ath = client.get(f"/api/sessions?athlete_id={test_athlete['id']}")
        assert res_ath.status_code == 200
        ath_sessions = res_ath.json()
        assert len(ath_sessions) >= 1
        assert all(sess["athlete_id"] == test_athlete["id"] for sess in ath_sessions)

        # Filter by status
        res_status = client.get("/api/sessions?status=in_progress")
        assert res_status.status_code == 200
        prog_sessions = res_status.json()
        assert all(sess["status"] == "in_progress" for sess in prog_sessions)

    def test_session_manual_completion(self, client, test_athlete):
        s = client.post(
            "/api/sessions",
            json={
                "athlete_id": test_athlete["id"],
                "bow_category": "Compound",
                "session_type": "training",
                "distance": "50m",
                "arrows_per_end": 3,
                "total_ends": 10,
            },
        ).json()
        session_id = s["id"]
        assert s["status"] == "in_progress"

        # Mark completed prematurely
        comp_res = client.patch(f"/api/sessions/{session_id}/complete")
        assert comp_res.status_code == 200
        assert comp_res.json()["status"] == "completed"

        # Verify through GET
        get_res = client.get(f"/api/sessions/{session_id}")
        assert get_res.json()["session"]["status"] == "completed"

    def test_session_deletion(self, client, test_athlete):
        s = client.post(
            "/api/sessions",
            json={
                "athlete_id": test_athlete["id"],
                "bow_category": "Recurve",
                "session_type": "training",
                "distance": "70m",
                "arrows_per_end": 3,
                "total_ends": 2,
            },
        ).json()
        session_id = s["id"]

        # Delete session
        del_res = client.delete(f"/api/sessions/{session_id}")
        assert del_res.status_code == 200
        assert del_res.json()["status"] == "success"

        # Confirm 404 on subsequent get
        get_res = client.get(f"/api/sessions/{session_id}")
        assert get_res.status_code == 404


# ==========================================
# 4. END RECORDING, SCORING & ARROW VALIDATION
# ==========================================
class TestScoringCalculationsAndEquivalence:
    @pytest.fixture
    def active_session(self, client):
        ath = client.post("/api/athletes", json={"name": f"Shooter-{uuid.uuid4().hex[:4]}"}).json()
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
        return sess

    def test_record_end_with_full_score_spectrum(self, client, active_session):
        # End 1: X, 10, 9, 8, 1, M -> total: 10+10+9+8+1+0 = 38, X count = 1
        end1_payload = {
            "end_number": 1,
            "arrows": [
                {"arrow_number": 1, "score": "X", "is_x": True},
                {"arrow_number": 2, "score": "10", "is_x": False},
                {"arrow_number": 3, "score": "9"},
                {"arrow_number": 4, "score": "8"},
                {"arrow_number": 5, "score": "1"},
                {"arrow_number": 6, "score": "M"},
            ],
        }
        res = client.post(f"/api/sessions/{active_session['id']}/ends", json=end1_payload)
        assert res.status_code == 201
        data = res.json()
        assert data["total_score"] == 38
        assert data["x_count"] == 1
        assert data["end_number"] == 1

        # Check session score summary after End 1
        score_res = client.get(f"/api/sessions/{active_session['id']}/score")
        assert score_res.status_code == 200
        summary = score_res.json()
        assert summary["total_score"] == 38
        assert summary["total_x"] == 1
        assert summary["total_arrows"] == 6
        assert summary["average_score_per_arrow"] == round(38 / 6, 2)
        assert summary["average_score_per_end"] == 38.0

    def test_edit_previous_end_updates_cumulative_scores(self, client, active_session):
        # Record End 1: all 10s (60 pts, 0 X)
        client.post(
            f"/api/sessions/{active_session['id']}/ends",
            json={
                "end_number": 1,
                "arrows": [{"arrow_number": i + 1, "score": 10} for i in range(6)],
            },
        )

        # Edit End 1: replace arrows with all X's (60 pts, 6 X)
        update_payload = {
            "arrows": [{"arrow_number": i + 1, "score": "X", "is_x": True} for i in range(6)],
        }
        update_res = client.put(f"/api/sessions/{active_session['id']}/ends/1", json=update_payload)
        assert update_res.status_code == 200
        updated = update_res.json()
        assert updated["total_score"] == 60
        assert updated["x_count"] == 6

        # Check session score
        score_res = client.get(f"/api/sessions/{active_session['id']}/score")
        assert score_res.json()["total_x"] == 6

    def test_session_auto_completion_on_final_end(self, client, active_session):
        # End 1
        client.post(
            f"/api/sessions/{active_session['id']}/ends",
            json={"end_number": 1, "arrows": [{"arrow_number": i + 1, "score": 9} for i in range(6)]},
        )
        # End 2 (Final End)
        res_end2 = client.post(
            f"/api/sessions/{active_session['id']}/ends",
            json={"end_number": 2, "arrows": [{"arrow_number": i + 1, "score": 10} for i in range(6)]},
        )
        assert res_end2.status_code == 201

        # Session should now be completed automatically
        details = client.get(f"/api/sessions/{active_session['id']}").json()
        assert details["session"]["status"] == "completed"
        assert details["summary"]["total_score"] == 54 + 60  # 114
        assert details["summary"]["highest_scoring_end"]["end_number"] == 2
        assert details["summary"]["highest_scoring_end"]["score"] == 60
        assert details["summary"]["lowest_scoring_end"]["end_number"] == 1
        assert details["summary"]["lowest_scoring_end"]["score"] == 54

        # Cannot submit additional ends to completed session
        over_res = client.post(
            f"/api/sessions/{active_session['id']}/ends",
            json={"end_number": 3, "arrows": [{"arrow_number": 1, "score": 10}]},
        )
        assert over_res.status_code == 400
        assert "completed session" in over_res.json()["detail"].lower()


# ==========================================
# 5. AI TARGET DETECTION BLACK BOX
# ==========================================
class TestAiTargetDetectionBlackBox:
    def test_detect_target_valid_image(self, client):
        # Create session
        ath = client.post("/api/athletes", json={"name": "AI Target Test Athlete"}).json()
        sess = client.post(
            "/api/sessions",
            json={
                "athlete_id": ath["id"],
                "bow_category": "Recurve",
                "session_type": "training",
                "distance": "70m",
                "arrows_per_end": 6,
                "total_ends": 5,
            },
        ).json()

        # Create dummy target face image
        img = np.zeros((300, 300, 3), dtype=np.uint8)
        cv2.circle(img, (150, 150), 120, (255, 255, 255), -1)
        cv2.circle(img, (150, 150), 40, (0, 215, 255), -1)  # Yellow center

        _, encoded = cv2.imencode(".jpeg", img)
        buf = io.BytesIO(encoded.tobytes())

        res = client.post(
            f"/api/sessions/{sess['id']}/detect",
            files={"file": ("target.jpeg", buf, "image/jpeg")},
        )
        assert res.status_code == 200
        data = res.json()
        assert "target" in data
        assert "detected_arrows" in data
        assert len(data["detected_arrows"]) == 6
        assert data["session_id"] == sess["id"]

    def test_detect_target_on_completed_session_rejected(self, client):
        ath = client.post("/api/athletes", json={"name": "Completed Target Athlete"}).json()
        sess = client.post(
            "/api/sessions",
            json={
                "athlete_id": ath["id"],
                "bow_category": "Recurve",
                "session_type": "training",
                "distance": "70m",
                "arrows_per_end": 3,
                "total_ends": 1,
            },
        ).json()
        # Complete session
        client.patch(f"/api/sessions/{sess['id']}/complete")

        img = np.zeros((100, 100, 3), dtype=np.uint8)
        _, encoded = cv2.imencode(".jpeg", img)
        buf = io.BytesIO(encoded.tobytes())

        res = client.post(
            f"/api/sessions/{sess['id']}/detect",
            files={"file": ("target.jpeg", buf, "image/jpeg")},
        )
        assert res.status_code == 400
        assert "completed session" in res.json()["detail"].lower()
