from typing import Optional, List, Dict, Any
from database import execute_query, execute_insert, execute_update


async def create_session(
    athlete_id: int,
    bow_category: str,
    session_type: str,
    distance: str,
    arrows_per_end: int,
    total_ends: int,
) -> int:
    sql = """
        INSERT INTO scoring_sessions 
        (athlete_id, bow_category, session_type, distance, arrows_per_end, total_ends, current_end, status, started_at)
        VALUES (%s, %s, %s, %s, %s, %s, 1, 'in_progress', NOW())
    """
    return await execute_insert(
        sql,
        (athlete_id, bow_category, session_type, distance, arrows_per_end, total_ends),
    )


async def get_session_by_id(session_id: int) -> Optional[Dict[str, Any]]:
    sql = """
        SELECT 
            s.id, s.athlete_id, a.name as athlete_name, a.athlete_code,
            s.bow_category, s.session_type, s.distance, s.arrows_per_end,
            s.total_ends, s.current_end, s.status, s.started_at, s.completed_at, s.created_at
        FROM scoring_sessions s
        LEFT JOIN athletes a ON s.athlete_id = a.id
        WHERE s.id = %s
    """
    return await execute_query(sql, (session_id,), fetch_one=True)


async def list_sessions(
    athlete_id: Optional[int] = None,
    status: Optional[str] = None,
    limit: int = 50,
) -> List[Dict[str, Any]]:
    conditions = []
    params = []

    if athlete_id is not None:
        conditions.append("s.athlete_id = %s")
        params.append(athlete_id)

    if status is not None:
        conditions.append("s.status = %s")
        params.append(status)

    where_clause = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    params.append(limit)

    sql = f"""
        SELECT 
            s.id, s.athlete_id, a.name as athlete_name, a.athlete_code,
            s.bow_category, s.session_type, s.distance, s.arrows_per_end,
            s.total_ends, s.current_end, s.status, s.started_at, s.completed_at, s.created_at
        FROM scoring_sessions s
        LEFT JOIN athletes a ON s.athlete_id = a.id
        {where_clause}
        ORDER BY s.id DESC
        LIMIT %s
    """
    return await execute_query(sql, tuple(params))


async def update_session_current_end(session_id: int, current_end: int) -> int:
    sql = "UPDATE scoring_sessions SET current_end = %s WHERE id = %s"
    return await execute_update(sql, (current_end, session_id))


async def update_session_status(session_id: int, status: str, completed: bool = False) -> int:
    if completed:
        sql = "UPDATE scoring_sessions SET status = %s, completed_at = NOW() WHERE id = %s"
    else:
        sql = "UPDATE scoring_sessions SET status = %s WHERE id = %s"
    return await execute_update(sql, (status, session_id))


async def delete_session(session_id: int) -> bool:
    sql = "DELETE FROM scoring_sessions WHERE id = %s"
    rows = await execute_update(sql, (session_id,))
    return rows > 0
