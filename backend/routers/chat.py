"""Chat Monitor router.
Analyzes batches of chat screenshot frames for romance scam patterns.
"""

import logging

from typing import List

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from services.llm import analyze_chat_frames

router = APIRouter(tags=["Chat Monitor"])
logger = logging.getLogger(__name__)


def _status_code_for_value_error(exc: ValueError) -> int:
    message = str(exc)
    if "is missing. Set it in your .env file." in message:
        return 500
    return 400


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
        raise HTTPException(status_code=_status_code_for_value_error(exc), detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        logger.exception("Chat analysis failed for session %s", req.session_id)
        raise HTTPException(status_code=500, detail="Failed to analyze chat frames") from exc

    return RiskReport(**result.model_dump())
