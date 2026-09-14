import os
import asyncio
import aiomysql
from dotenv import load_dotenv
from os import getenv

load_dotenv()

pool = None


async def init_pool():
    global pool
    loop = asyncio.get_running_loop()

    if pool is not None:
        if pool._loop is loop and not pool._loop.is_closed():
            return pool
        try:
            pool.close()
            await pool.wait_closed()
        except Exception:
            pass
        pool = None

    host = getenv("DB_HOST", "127.0.0.1")
    port = int(getenv("DB_PORT", 3306))
    user = getenv("DB_USER", "root")
    password = getenv("DB_PASSWORD", "")
    db_name = getenv("DB_NAME", "archery_scoring_db")

    pool = await aiomysql.create_pool(
        host=host,
        port=port,
        user=user,
        password=password,
        db=db_name,
        autocommit=True,
        minsize=1,
        maxsize=10,
        loop=loop,
    )
    # Ensure tables exist
    await init_db_schema()
    return pool


async def init_db_schema():
    """Initializes schema if tables do not exist."""
    schema_file = os.path.join(os.path.dirname(__file__), "schema.sql")
    if not os.path.exists(schema_file):
        return

    with open(schema_file, "r", encoding="utf-8") as f:
        sql_content = f.read()

    statements = [s.strip() for s in sql_content.split(";") if s.strip()]
    async with pool.acquire() as conn:
        async with conn.cursor() as cursor:
            await cursor.execute("SET sql_notes = 0;")
            for statement in statements:
                upper_stmt = statement.upper()
                if upper_stmt.startswith("CREATE DATABASE") or upper_stmt.startswith("USE "):
                    continue
                try:
                    await cursor.execute(statement)
                except Exception:
                    pass
            await cursor.execute("SET sql_notes = 1;")


async def get_active_pool():
    global pool
    loop = asyncio.get_running_loop()
    if pool is None or pool._loop is not loop or pool._loop.is_closed():
        await init_pool()
    return pool


async def execute_query(sql: str, params=None, fetch_one: bool = False):
    """Executes a SELECT query and returns rows as dictionaries."""
    active_pool = await get_active_pool()
    async with active_pool.acquire() as conn:
        async with conn.cursor(aiomysql.DictCursor) as cursor:
            await cursor.execute(sql, params)
            if fetch_one:
                return await cursor.fetchone()
            return await cursor.fetchall()


async def execute_insert(sql: str, params=None) -> int:
    """Executes an INSERT statement and returns the last inserted row ID."""
    active_pool = await get_active_pool()
    async with active_pool.acquire() as conn:
        async with conn.cursor() as cursor:
            await cursor.execute(sql, params)
            return cursor.lastrowid


async def execute_update(sql: str, params=None) -> int:
    """Executes an UPDATE or DELETE statement and returns affected rows count."""
    active_pool = await get_active_pool()
    async with active_pool.acquire() as conn:
        async with conn.cursor() as cursor:
            await cursor.execute(sql, params)
            return cursor.rowcount


async def close_pool():
    global pool
    if pool is not None:
        try:
            pool.close()
            await pool.wait_closed()
        except Exception:
            pass
        pool = None
