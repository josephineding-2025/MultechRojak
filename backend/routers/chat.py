"""Chat Monitor router.
Analyzes batches of chat screenshot frames for romance scam patterns.
"""

from typing import List

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from services.llm import analyze_chat_frames

router = APIRouter(tags=["Chat Monitor"])


class ChatAnalysisRequest(BaseModel):
    frames: List[str]  # base64-encoded images
    platform: str
    session_id: str


class RedFlag(BaseModel):
    pattern: str
    evidence: str
    severity: str  # "critical" | "high" | "medium" | "low"


class RiskReport(BaseModel):
    risk_level: str  # "LOW" | "MEDIUM" | "HIGH" | "CRITICAL"
    risk_score: int  # 0-100
    red_flags: List[RedFlag]
    summary: str
    recommended_actions: List[str]


@router.post("/analyze-chat", response_model=RiskReport)
async def analyze_chat(req: ChatAnalysisRequest) -> RiskReport:
    """Analyze a batch of chat screenshot frames for romance scam patterns."""
    if not req.frames:
        raise HTTPException(status_code=400, detail="frames must contain at least one image")

    try:
        result = analyze_chat_frames(
            frames=req.frames,
            platform=req.platform,
            session_id=req.session_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail="Failed to analyze chat frames") from exc

    return RiskReport(**result.model_dump())
