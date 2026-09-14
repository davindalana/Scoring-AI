from typing import List, Dict, Any
from database import execute_query, execute_insert, execute_update


async def save_arrows_for_end(end_id: int, arrows: List[Dict[str, Any]]) -> bool:
    """
    Replaces all arrow records for the given end_id.
    Each item in arrows has: arrow_number, score, is_x, source ('manual' or 'ai').
    """
    # Delete existing arrows for this end to allow idempotent updates/edits
    await delete_arrows_by_end_id(end_id)

    sql = """
        INSERT INTO arrow_scores (end_id, arrow_number, score, is_x, source)
        VALUES (%s, %s, %s, %s, %s)
    """
    for a in arrows:
        await execute_insert(
            sql,
            (
                end_id,
                a["arrow_number"],
                a["score"],
                1 if a.get("is_x") else 0,
                a.get("source", "manual"),
            ),
        )
    return True


async def get_arrows_by_end_id(end_id: int) -> List[Dict[str, Any]]:
    sql = """
        SELECT id, end_id, arrow_number, score, is_x, source, created_at
        FROM arrow_scores
        WHERE end_id = %s
        ORDER BY arrow_number ASC
    """
    rows = await execute_query(sql, (end_id,))
    # Convert is_x to boolean for clean API serialization
    for r in rows:
        r["is_x"] = bool(r["is_x"])
    return rows


async def delete_arrows_by_end_id(end_id: int) -> bool:
    sql = "DELETE FROM arrow_scores WHERE end_id = %s"
    await execute_update(sql, (end_id,))
    return True
