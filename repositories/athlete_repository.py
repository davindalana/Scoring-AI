from typing import Optional, List, Dict, Any
from database import execute_query, execute_insert


async def create_athlete(name: str, athlete_code: Optional[str] = None) -> int:
    sql = "INSERT INTO athletes (name, athlete_code) VALUES (%s, %s)"
    return await execute_insert(sql, (name, athlete_code))


async def get_athlete_by_id(athlete_id: int) -> Optional[Dict[str, Any]]:
    sql = "SELECT id, name, athlete_code, created_at FROM athletes WHERE id = %s"
    return await execute_query(sql, (athlete_id,), fetch_one=True)


async def get_athlete_by_code(athlete_code: str) -> Optional[Dict[str, Any]]:
    sql = "SELECT id, name, athlete_code, created_at FROM athletes WHERE athlete_code = %s"
    return await execute_query(sql, (athlete_code,), fetch_one=True)


async def list_athletes(limit: int = 50) -> List[Dict[str, Any]]:
    sql = "SELECT id, name, athlete_code, created_at FROM athletes ORDER BY name ASC LIMIT %s"
    return await execute_query(sql, (limit,))
