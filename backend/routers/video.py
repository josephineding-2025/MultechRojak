"""
Video Monitor router — Owner: Member 2
Analyzes video call frames and audio chunks for suspicious patterns.
"""
from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(tags=["Video Monitor"])


class VideoFrameRequest(BaseModel):
    frame: str       # base64-encoded image
    session_id: str


class VideoAlert(BaseModel):
    alert: bool
    reason: str
    severity: str    # "critical" | "high" | "medium" | "low"


class AudioChunkRequest(BaseModel):
    audio_b64: str   # base64-encoded audio
    session_id: str


class AudioAlert(BaseModel):
    transcription: str
    alert: bool
    reason: str
    severity: str    # "critical" | "high" | "medium" | "low"


@router.post("/analyze-video-frame", response_model=VideoAlert)
async def analyze_video_frame(req: VideoFrameRequest) -> VideoAlert:
    """
    Analyze a single video call frame for visual anomalies.

    TODO (Member 2): Replace mock with real vision LLM analysis.
    See backend/services/llm/ for the implementation stub.
    """
    # --- MOCK RESPONSE — matches SPEC.md Section 8 exactly ---
    return VideoAlert(
        alert=True,
        reason="Face inconsistency detected across frames",
        severity="high",
    )


@router.post("/analyze-audio-chunk", response_model=AudioAlert)
async def analyze_audio_chunk(req: AudioChunkRequest) -> AudioAlert:
    """
    Transcribe and analyze an audio chunk from a live call.

    TODO (Member 2): Replace mock with Whisper transcription + LLM analysis.
    See backend/services/llm/ for the implementation stub.
    """
    # --- MOCK RESPONSE — matches SPEC.md Section 8 exactly ---
    return AudioAlert(
        transcription="Can you please send me $500 tonight...",
        alert=True,
        reason="Urgent money request detected in speech",
        severity="critical",
    )
