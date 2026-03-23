"""Video Monitor router.
Analyzes video call frames and audio chunks for suspicious patterns.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from services.llm import analyze_audio_chunk, analyze_video_frame

router = APIRouter(tags=["Video Monitor"])


def _status_code_for_value_error(exc: ValueError) -> int:
    message = str(exc)
    if "is missing. Set it in your .env file." in message:
        return 500
    return 400


class VideoFrameRequest(BaseModel):
    frame: str  # base64-encoded image
    session_id: str


class VideoAlert(BaseModel):
    alert: bool
    reason: str
    severity: str  # "critical" | "high" | "medium" | "low"


class AudioChunkRequest(BaseModel):
    audio_b64: str  # base64-encoded audio
    session_id: str


class AudioAlert(BaseModel):
    transcription: str
    alert: bool
    reason: str
    severity: str  # "critical" | "high" | "medium" | "low"


@router.post("/analyze-video-frame", response_model=VideoAlert)
async def analyze_video_frame_endpoint(req: VideoFrameRequest) -> VideoAlert:
    """Analyze a single video call frame for visual anomalies."""
    if not req.frame:
        raise HTTPException(status_code=400, detail="frame is required")

    try:
        result = analyze_video_frame(frame=req.frame, session_id=req.session_id)
    except ValueError as exc:
        raise HTTPException(status_code=_status_code_for_value_error(exc), detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail="Failed to analyze video frame") from exc

    return VideoAlert(**result.model_dump())


@router.post("/analyze-audio-chunk", response_model=AudioAlert)
async def analyze_audio_chunk_endpoint(req: AudioChunkRequest) -> AudioAlert:
    """Transcribe and analyze an audio chunk from a live call."""
    if not req.audio_b64:
        raise HTTPException(status_code=400, detail="audio_b64 is required")

    try:
        result = analyze_audio_chunk(audio_b64=req.audio_b64, session_id=req.session_id)
    except ValueError as exc:
        raise HTTPException(status_code=_status_code_for_value_error(exc), detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail="Failed to analyze audio chunk") from exc

    return AudioAlert(**result.model_dump())
