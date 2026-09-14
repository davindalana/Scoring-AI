from typing import Optional, List, Dict, Any
from fastapi import HTTPException
from models.scoring_models import (
    AthleteCreate,
    SessionCreate,
    EndCreate,
    EndUpdate,
)
from repositories.athlete_repository import (
    create_athlete,
    get_athlete_by_id,
    list_athletes,
)
from repositories.session_repository import (
    create_session,
    get_session_by_id,
    list_sessions,
    update_session_current_end,
    update_session_status,
    delete_session,
)
from repositories.end_repository import (
    save_end,
    get_ends_by_session_id,
    get_end_by_session_and_number,
)
from repositories.arrow_repository import (
    save_arrows_for_end,
    get_arrows_by_end_id,
)
from utils.scoring import (
    parse_arrow_score,
    calculate_end_score,
    calculate_session_score,
)


# Athlete Services
async def create_athlete_service(data: AthleteCreate) -> Dict[str, Any]:
    try:
        athlete_id = await create_athlete(data.name, data.athlete_code)
        return await get_athlete_by_id(athlete_id)
    except Exception as e:
        if "Duplicate entry" in str(e):
            raise HTTPException(
                status_code=400,
                detail=f"Athlete code '{data.athlete_code}' already exists.",
            )
        raise e


async def list_athletes_service(limit: int = 50) -> List[Dict[str, Any]]:
    return await list_athletes(limit)


async def get_athlete_service(athlete_id: int) -> Dict[str, Any]:
    if athlete_id <= 0:
        raise HTTPException(status_code=400, detail="Athlete ID must be a positive integer.")
    athlete = await get_athlete_by_id(athlete_id)
    if not athlete:
        raise HTTPException(status_code=404, detail=f"Athlete with ID {athlete_id} not found.")
    return athlete


# Session Services
async def create_session_service(data: SessionCreate) -> Dict[str, Any]:
    athlete = await get_athlete_by_id(data.athlete_id)
    if not athlete:
        raise HTTPException(status_code=404, detail=f"Athlete with ID {data.athlete_id} not found.")

    session_id = await create_session(
        athlete_id=data.athlete_id,
        bow_category=data.bow_category.value,
        session_type=data.session_type.value,
        distance=data.distance,
        arrows_per_end=data.arrows_per_end,
        total_ends=data.total_ends,
    )
    return await get_session_by_id(session_id)


async def get_session_details_service(session_id: int) -> Dict[str, Any]:
    if session_id <= 0:
        raise HTTPException(status_code=400, detail="Session ID must be a positive integer.")
    
    session = await get_session_by_id(session_id)
    if not session:
        raise HTTPException(status_code=404, detail=f"Session with ID {session_id} not found.")

    athlete = await get_athlete_by_id(session["athlete_id"])

    # Load ends and arrows
    raw_ends = await get_ends_by_session_id(session_id)
    ends_with_arrows = []
    for end in raw_ends:
        arrows = await get_arrows_by_end_id(end["id"])
        end_copy = dict(end)
        end_copy["arrows"] = arrows
        ends_with_arrows.append(end_copy)

    summary = calculate_session_score(ends_with_arrows)
    summary["session_id"] = session_id

    return {
        "session": session,
        "athlete": athlete,
        "summary": summary,
        "ends": ends_with_arrows,
    }


async def list_sessions_service(
    athlete_id: Optional[int] = None,
    status: Optional[str] = None,
    limit: int = 50,
) -> List[Dict[str, Any]]:
    return await list_sessions(athlete_id=athlete_id, status=status, limit=limit)


async def complete_session_service(session_id: int) -> Dict[str, Any]:
    if session_id <= 0:
        raise HTTPException(status_code=400, detail="Session ID must be a positive integer.")
    session = await get_session_by_id(session_id)
    if not session:
        raise HTTPException(status_code=404, detail=f"Session with ID {session_id} not found.")

    await update_session_status(session_id, "completed", completed=True)
    return await get_session_by_id(session_id)


async def delete_session_service(session_id: int) -> Dict[str, Any]:
    if session_id <= 0:
        raise HTTPException(status_code=400, detail="Session ID must be a positive integer.")
    deleted = await delete_session(session_id)
    if not deleted:
        raise HTTPException(status_code=404, detail=f"Session with ID {session_id} not found.")
    return {"status": "success", "message": f"Session {session_id} deleted successfully."}


# End & Score Services
async def record_end_service(session_id: int, data: EndCreate) -> Dict[str, Any]:
    if session_id <= 0:
        raise HTTPException(status_code=400, detail="Session ID must be a positive integer.")

    session = await get_session_by_id(session_id)
    if not session:
        raise HTTPException(status_code=404, detail=f"Session with ID {session_id} not found.")

    if session["status"] == "completed":
        raise HTTPException(status_code=400, detail="Cannot record ends for a completed session.")

    if data.end_number <= 0 or data.end_number > session["total_ends"]:
        raise HTTPException(
            status_code=400,
            detail=f"End number {data.end_number} is out of range. Session has {session['total_ends']} ends.",
        )

    if len(data.arrows) > session["arrows_per_end"]:
        raise HTTPException(
            status_code=400,
            detail=f"Too many arrows for this end. Maximum allowed is {session['arrows_per_end']}, got {len(data.arrows)}.",
        )

    # Validate and normalize arrows
    normalized_arrows = []
    for a in data.arrows:
        if a.arrow_number <= 0 or a.arrow_number > session["arrows_per_end"]:
            raise HTTPException(
                status_code=400,
                detail=f"Arrow number {a.arrow_number} is out of bounds (1-{session['arrows_per_end']}).",
            )
        score_val, is_x = parse_arrow_score(a.score, a.is_x)
        normalized_arrows.append({
            "arrow_number": a.arrow_number,
            "score": score_val,
            "is_x": is_x,
            "source": a.source.value if hasattr(a.source, "value") else str(a.source),
        })

    # Calculate end stats
    end_calc = calculate_end_score(normalized_arrows)

    # Save end to DB
    end_id = await save_end(
        session_id=session_id,
        end_number=data.end_number,
        total_score=end_calc["total_score"],
        x_count=end_calc["x_count"],
    )

    # Save arrows
    await save_arrows_for_end(end_id, normalized_arrows)

    # Update session current_end if appropriate
    if data.end_number >= session["current_end"] and session["current_end"] < session["total_ends"]:
        await update_session_current_end(session_id, data.end_number + 1)
    elif data.end_number == session["total_ends"]:
        # Mark completed when the last end is submitted
        await update_session_status(session_id, "completed", completed=True)

    saved_arrows = await get_arrows_by_end_id(end_id)
    return {
        "id": end_id,
        "session_id": session_id,
        "end_number": data.end_number,
        "total_score": end_calc["total_score"],
        "x_count": end_calc["x_count"],
        "arrows": saved_arrows,
    }


async def update_end_service(session_id: int, end_number: int, data: EndUpdate) -> Dict[str, Any]:
    if session_id <= 0:
        raise HTTPException(status_code=400, detail="Session ID must be a positive integer.")

    session = await get_session_by_id(session_id)
    if not session:
        raise HTTPException(status_code=404, detail=f"Session with ID {session_id} not found.")

    if session["status"] == "completed":
        raise HTTPException(status_code=400, detail="Cannot edit ends for a completed session.")

    existing_end = await get_end_by_session_and_number(session_id, end_number)
    if not existing_end:
        raise HTTPException(status_code=404, detail=f"End number {end_number} not found in session {session_id}.")

    if len(data.arrows) > session["arrows_per_end"]:
        raise HTTPException(
            status_code=400,
            detail=f"Too many arrows for this end. Maximum allowed is {session['arrows_per_end']}, got {len(data.arrows)}.",
        )

    normalized_arrows = []
    for a in data.arrows:
        if a.arrow_number <= 0 or a.arrow_number > session["arrows_per_end"]:
            raise HTTPException(
                status_code=400,
                detail=f"Arrow number {a.arrow_number} is out of bounds (1-{session['arrows_per_end']}).",
            )
        score_val, is_x = parse_arrow_score(a.score, a.is_x)
        normalized_arrows.append({
            "arrow_number": a.arrow_number,
            "score": score_val,
            "is_x": is_x,
            "source": a.source.value if hasattr(a.source, "value") else str(a.source),
        })

    end_calc = calculate_end_score(normalized_arrows)
    end_id = await save_end(
        session_id=session_id,
        end_number=end_number,
        total_score=end_calc["total_score"],
        x_count=end_calc["x_count"],
    )

    await save_arrows_for_end(end_id, normalized_arrows)
    saved_arrows = await get_arrows_by_end_id(end_id)

    return {
        "id": end_id,
        "session_id": session_id,
        "end_number": end_number,
        "total_score": end_calc["total_score"],
        "x_count": end_calc["x_count"],
        "arrows": saved_arrows,
    }


async def get_session_score_summary_service(session_id: int) -> Dict[str, Any]:
    if session_id <= 0:
        raise HTTPException(status_code=400, detail="Session ID must be a positive integer.")

    session = await get_session_by_id(session_id)
    if not session:
        raise HTTPException(status_code=404, detail=f"Session with ID {session_id} not found.")

    raw_ends = await get_ends_by_session_id(session_id)
    ends_with_arrows = []
    for end in raw_ends:
        arrows = await get_arrows_by_end_id(end["id"])
        end_copy = dict(end)
        end_copy["arrows"] = arrows
        ends_with_arrows.append(end_copy)

    summary = calculate_session_score(ends_with_arrows)
    summary["session_id"] = session_id
    return summary
