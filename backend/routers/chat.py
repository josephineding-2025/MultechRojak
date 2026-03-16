"""
Chat Monitor router — Owner: Member 2
Analyzes batches of chat screenshot frames for romance scam patterns.
"""
from fastapi import APIRouter
from pydantic import BaseModel
from typing import List

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
    risk_level: str          # "LOW" | "MEDIUM" | "HIGH" | "CRITICAL"
    risk_score: int          # 0–100
    red_flags: List[RedFlag]
    summary: str
    recommended_actions: List[str]


@router.post("/analyze-chat", response_model=RiskReport)
async def analyze_chat(req: ChatAnalysisRequest) -> RiskReport:
    """
    Analyze a batch of chat screenshot frames for romance scam patterns.

    TODO (Member 2): Replace mock return with real LangChain + GPT-4o pipeline.
    See backend/services/llm/ for the implementation stub.
    """
    # --- MOCK RESPONSE — matches SPEC.md Section 8 exactly ---
    return RiskReport(
        risk_level="HIGH",
        risk_score=82,
        red_flags=[
            RedFlag(
                pattern="Urgent money request",
                evidence="Message: 'Please send $500 by tonight or I lose everything'",
                severity="critical",
            ),
            RedFlag(
                pattern="Avoided video verification",
                evidence="Three separate excuses given when video call was suggested",
                severity="high",
            ),
        ],
        summary=(
            "This conversation shows multiple high-severity romance scam indicators "
            "including urgent financial requests and consistent avoidance of identity verification."
        ),
        recommended_actions=[
            "Do not send money or gift cards",
            "Request an in-person or verified video meeting",
            "Report to your local cybercrime authority",
        ],
    )
