from contextlib import asynccontextmanager
from os import getenv, path
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from database import init_pool, close_pool
import routes

load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: initialize connection pool and tables
    try:
        await init_pool()
    except Exception as e:
        print(f"Warning: Could not connect to MySQL pool on startup: {e}")
    yield
    # Shutdown: cleanly close pool
    await close_pool()


app = FastAPI(
    title="Archery Scoring Application",
    description="Manual & AI-assisted archery scoring system for athletes and coaches.",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS setup
allowed_origins = [
    "http://localhost:3000",
    "http://localhost:5173",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:5173",
    "http://localhost:8000",
    "http://127.0.0.1:8000",
]
custom_origin = getenv("REACT_URL")
if custom_origin:
    allowed_origins.append(f"http://{custom_origin}")
    allowed_origins.append(f"https://{custom_origin}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Open in development for testing
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API Routers
# 1. Scoring MVP API
app.include_router(routes.scoring_router, prefix="/api")

# 2. Legacy Target & Arrow Detection Router
app.include_router(
    routes.score_detection_router,
    prefix=f"/api/{routes.score_detection_route_prefix}",
)

# Static files and Web UI
static_dir = path.join(path.dirname(__file__), "static")
if path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")


@app.get("/")
@app.get("/app")
async def serve_ui():
    index_file = path.join(path.dirname(__file__), "static", "index.html")
    if path.exists(index_file):
        return FileResponse(index_file)
    return {"message": "Archery Scoring Application API is running. Static UI not yet mounted."}


@app.get("/health")
async def health_check():
    return {"status": "ok", "app": "Archery Scoring Application"}
