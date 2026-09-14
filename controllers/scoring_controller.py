from typing import Optional
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse
from models.scoring_models import (
    AthleteCreate,
    SessionCreate,
    EndCreate,
    EndUpdate,
)
from services.scoring_service import (
    create_athlete_service,
    list_athletes_service,
    get_athlete_service,
    create_session_service,
    list_sessions_service,
    get_session_details_service,
    complete_session_service,
    delete_session_service,
    record_end_service,
    update_end_service,
    get_session_score_summary_service,
)


async def create_athlete_controller(data: AthleteCreate):
    result = await create_athlete_service(data)
    return JSONResponse(status_code=201, content=jsonable_encoder(result))


async def list_athletes_controller():
    result = await list_athletes_service()
    return JSONResponse(status_code=200, content=jsonable_encoder(result))


async def get_athlete_controller(athlete_id: int):
    result = await get_athlete_service(athlete_id)
    return JSONResponse(status_code=200, content=jsonable_encoder(result))


async def create_session_controller(data: SessionCreate):
    result = await create_session_service(data)
    return JSONResponse(status_code=201, content=jsonable_encoder(result))


async def list_sessions_controller(
    athlete_id: Optional[int] = None,
    status: Optional[str] = None,
):
    result = await list_sessions_service(athlete_id=athlete_id, status=status)
    return JSONResponse(status_code=200, content=jsonable_encoder(result))


async def get_session_details_controller(session_id: int):
    result = await get_session_details_service(session_id)
    return JSONResponse(status_code=200, content=jsonable_encoder(result))


async def complete_session_controller(session_id: int):
    result = await complete_session_service(session_id)
    return JSONResponse(status_code=200, content=jsonable_encoder(result))


async def delete_session_controller(session_id: int):
    result = await delete_session_service(session_id)
    return JSONResponse(status_code=200, content=jsonable_encoder(result))


async def record_end_controller(session_id: int, data: EndCreate):
    result = await record_end_service(session_id, data)
    return JSONResponse(status_code=201, content=jsonable_encoder(result))


async def update_end_controller(session_id: int, end_number: int, data: EndUpdate):
    result = await update_end_service(session_id, end_number, data)
    return JSONResponse(status_code=200, content=jsonable_encoder(result))


async def get_session_score_controller(session_id: int):
    result = await get_session_score_summary_service(session_id)
    return JSONResponse(status_code=200, content=jsonable_encoder(result))
