from enum import Enum
from typing import Optional, List, Union, Any, Dict
from pydantic import BaseModel, Field, field_validator
from utils.scoring import parse_arrow_score


class BowCategory(str, Enum):
    RECURVE = "Recurve"
    COMPOUND = "Compound"
    BAREBOW = "Barebow"
    STANDARD_BOW = "Standard Bow / National"


class SessionType(str, Enum):
    TRAINING = "training"
    COMPETITION = "competition"


class SessionStatus(str, Enum):
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    ABANDONED = "abandoned"


class ScoreSource(str, Enum):
    MANUAL = "manual"
    AI = "ai"


# Athlete Models
class AthleteCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    athlete_code: Optional[str] = Field(None, max_length=100)

    @field_validator("name")
    def name_not_empty(cls, v: str):
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("Athlete name cannot be empty")
        return cleaned


class AthleteResponse(BaseModel):
    id: int
    name: str
    athlete_code: Optional[str] = None
    created_at: Optional[Any] = None


# Session Models
class SessionCreate(BaseModel):
    athlete_id: int = Field(..., gt=0, description="Athlete ID must be positive")
    bow_category: BowCategory
    session_type: SessionType = SessionType.TRAINING
    distance: str = Field("18m", min_length=1, max_length=50)
    arrows_per_end: int = Field(6, ge=1, le=12, description="Arrows per end between 1 and 12")
    total_ends: int = Field(10, ge=1, le=50, description="Total ends between 1 and 50")


class SessionResponse(BaseModel):
    id: int
    athlete_id: int
    athlete_name: Optional[str] = None
    athlete_code: Optional[str] = None
    bow_category: BowCategory
    session_type: SessionType
    distance: str
    arrows_per_end: int
    total_ends: int
    current_end: int
    status: SessionStatus
    started_at: Optional[Any] = None
    completed_at: Optional[Any] = None
    created_at: Optional[Any] = None


# Arrow Models
class ArrowInput(BaseModel):
    arrow_number: int = Field(..., ge=1, le=12)
    score: Union[str, int]
    is_x: bool = False
    source: ScoreSource = ScoreSource.MANUAL

    @field_validator("score")
    def validate_score_value(cls, v, info):
        # Validate through scoring parser
        parse_arrow_score(v)
        return v


class ArrowResponse(BaseModel):
    id: int
    end_id: int
    arrow_number: int
    score: int
    is_x: bool
    source: str
    created_at: Optional[Any] = None


# End Models
class EndCreate(BaseModel):
    end_number: int = Field(..., ge=1, le=50)
    arrows: List[ArrowInput]

    @field_validator("arrows")
    def validate_arrows(cls, v):
        if not v:
            raise ValueError("Arrow scores list cannot be empty")
        # Check duplicate arrow numbers
        arrow_nums = [a.arrow_number for a in v]
        if len(arrow_nums) != len(set(arrow_nums)):
            raise ValueError("Duplicate arrow numbers detected in the same end")
        return v


class EndUpdate(BaseModel):
    arrows: List[ArrowInput]

    @field_validator("arrows")
    def validate_arrows(cls, v):
        if not v:
            raise ValueError("Arrow scores list cannot be empty")
        arrow_nums = [a.arrow_number for a in v]
        if len(arrow_nums) != len(set(arrow_nums)):
            raise ValueError("Duplicate arrow numbers detected in the same end")
        return v


class EndResponse(BaseModel):
    id: int
    session_id: int
    end_number: int
    total_score: int
    x_count: int
    arrows: List[ArrowResponse] = []
    created_at: Optional[Any] = None


# Detailed Session Summary Models
class SessionScoreSummary(BaseModel):
    session_id: int
    total_score: int
    total_x: int
    total_arrows: int
    total_ends: int
    average_score_per_arrow: float
    average_score_per_end: float
    highest_scoring_end: Optional[Dict[str, Any]] = None
    lowest_scoring_end: Optional[Dict[str, Any]] = None
    ends_summary: List[Dict[str, Any]] = []


class SessionDetailResponse(BaseModel):
    session: SessionResponse
    athlete: Optional[AthleteResponse] = None
    summary: SessionScoreSummary
    ends: List[EndResponse] = []
