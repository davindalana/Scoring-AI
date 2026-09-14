from .score_detection_routes import router as score_detection_router
from .score_detection_routes import router_prefix as score_detection_route_prefix
from .scoring_routes import router as scoring_router

__all__ = [
    "score_detection_router",
    "score_detection_route_prefix",
    "scoring_router",
]
