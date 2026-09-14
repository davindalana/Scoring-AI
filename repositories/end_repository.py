from typing import Optional, List, Dict, Any
from database import execute_query, execute_insert, execute_update


async def save_end(
    session_id: int,
    end_number: int,
    total_score: int,
    x_count: int,
) -> int:
    """
    Saves an end. If already exists for this session and end_number, updates total_score and x_count.
    Returns the end ID.
    """
    existing = await get_end_by_session_and_number(session_id, end_number)
    if existing:
        sql = "UPDATE scoring_ends SET total_score = %s, x_count = %s WHERE id = %s"
        await execute_update(sql, (total_score, x_count, existing["id"]))
        return existing["id"]

    sql = """
        INSERT INTO scoring_ends (session_id, end_number, total_score, x_count)
        VALUES (%s, %s, %s, %s)
    """
    return await execute_insert(sql, (session_id, end_number, total_score, x_count))


async def get_ends_by_session_id(session_id: int) -> List[Dict[str, Any]]:
    sql = """
        SELECT id, session_id, end_number, total_score, x_count, created_at
        FROM scoring_ends
        WHERE session_id = %s
        ORDER BY end_number ASC
    """
    return await execute_query(sql, (session_id,))


async def get_end_by_session_and_number(session_id: int, end_number: int) -> Optional[Dict[str, Any]]:
    sql = """
        SELECT id, session_id, end_number, total_score, x_count, created_at
        FROM scoring_ends
        WHERE session_id = %s AND end_number = %s
    """
    return await execute_query(sql, (session_id, end_number), fetch_one=True)


async def delete_end(end_id: int) -> bool:
    sql = "DELETE FROM scoring_ends WHERE id = %s"
    rows = await execute_update(sql, (end_id,))
    return rows > 0
