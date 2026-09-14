from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from os import getenv, makedirs, remove
import os
import uuid

from models.scoring_models import (
    AthleteCreate,
    SessionCreate,
    EndCreate,
    EndUpdate,
)
from controllers.scoring_controller import (
    create_athlete_controller,
    list_athletes_controller,
    get_athlete_controller,
    create_session_controller,
    list_sessions_controller,
    get_session_details_controller,
    complete_session_controller,
    delete_session_controller,
    record_end_controller,
    update_end_controller,
    get_session_score_controller,
)
from repositories.session_repository import get_session_by_id
from ml.target_detector import ArcheryTargetDetector

router = APIRouter()
tag_athletes = "Athletes"
tag_sessions = "Scoring Sessions"
tag_ends = "Scoring Ends"
tag_detection = "AI Target Detection"


# Athletes Endpoints
@router.post("/athletes", tags=[tag_athletes])
async def create_athlete(data: AthleteCreate):
    """Register a new athlete."""
    return await create_athlete_controller(data)


@router.get("/athletes", tags=[tag_athletes])
async def list_athletes():
    """Retrieve list of all athletes."""
    return await list_athletes_controller()


@router.get("/athletes/{athlete_id}", tags=[tag_athletes])
async def get_athlete(athlete_id: int):
    """Retrieve athlete by ID."""
    return await get_athlete_controller(athlete_id)


# Sessions Endpoints
@router.post("/sessions", tags=[tag_sessions])
async def create_session(data: SessionCreate):
    """Create a new scoring session."""
    return await create_session_controller(data)


@router.get("/sessions", tags=[tag_sessions])
async def list_sessions(
    athlete_id: Optional[int] = None,
    status: Optional[str] = None,
):
    """List recent scoring sessions with optional filters."""
    return await list_sessions_controller(athlete_id=athlete_id, status=status)


@router.get("/sessions/{session_id}", tags=[tag_sessions])
async def get_session_details(session_id: int):
    """Get complete session information, ends, and current calculated score."""
    return await get_session_details_controller(session_id)


@router.delete("/sessions/{session_id}", tags=[tag_sessions])
async def delete_session(session_id: int):
    """Delete a scoring session and all associated ends/arrows."""
    return await delete_session_controller(session_id)


@router.patch("/sessions/{session_id}/complete", tags=[tag_sessions])
async def complete_session(session_id: int):
    """Manually mark an in-progress session as completed."""
    return await complete_session_controller(session_id)


# Ends & Scoring Endpoints
@router.post("/sessions/{session_id}/ends", tags=[tag_ends])
async def record_end(session_id: int, data: EndCreate):
    """Record scores for an end."""
    return await record_end_controller(session_id, data)


@router.put("/sessions/{session_id}/ends/{end_number}", tags=[tag_ends])
async def update_end(session_id: int, end_number: int, data: EndUpdate):
    """Edit or correct scores for a previously recorded end."""
    return await update_end_controller(session_id, end_number, data)


@router.get("/sessions/{session_id}/score", tags=[tag_ends])
async def get_session_score(session_id: int):
    """Get calculated summary scores and statistics for a session."""
    return await get_session_score_controller(session_id)


# AI Target Detection Endpoint for Sessions
@router.post("/sessions/{session_id}/detect", tags=[tag_detection])
async def detect_session_end_target(
    session_id: int,
    file: UploadFile = File(...),
):
    """
    AI Target & Arrow Detection for a session end.
    Analyzes the target image and returns proposed arrow scores
    for the athlete to review and confirm before saving.
    """
    session = await get_session_by_id(session_id)
    if not session:
        raise HTTPException(status_code=404, detail=f"Session with ID {session_id} not found.")

    if session["status"] == "completed":
        raise HTTPException(status_code=400, detail="Cannot run detection on a completed session.")

    upload_dir = getenv("UPLOAD_DIR", "uploads")
    makedirs(upload_dir, exist_ok=True)
    temp_filename = f"{upload_dir}/session_{session_id}_{uuid.uuid4().hex[:8]}.jpeg"

    try:
        content = await file.read()
        with open(temp_filename, "wb") as buffer:
            buffer.write(content)

        detector = ArcheryTargetDetector(roboflow_api_key=getenv("ROBOFLOW_API"))
        result = await detector.detect(
            image_path=temp_filename,
            arrows_per_end=session["arrows_per_end"],
        )
        result["session_id"] = session_id
        result["current_end"] = session["current_end"]
        return result
    finally:
        if os.path.exists(temp_filename):
            remove(temp_filename)
