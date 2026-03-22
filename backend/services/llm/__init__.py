"""LLM services for chat/video analysis and audio transcription."""

from __future__ import annotations

import base64
import io
import os
from collections import Counter
from typing import List, Sequence

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_openai import ChatOpenAI
from openai import OpenAI
from pydantic import BaseModel, Field

OPENROUTER_BASE_URL = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
DEFAULT_MODEL = os.getenv("OPENROUTER_CHAT_MODEL", "google/gemini-flash-1.5")


class RedFlagResult(BaseModel):
    pattern: str
    evidence: str
    severity: str


class RiskReportResult(BaseModel):
    risk_level: str
    risk_score: int = Field(ge=0, le=100)
    red_flags: List[RedFlagResult]
    summary: str
    recommended_actions: List[str]


class VideoAlertResult(BaseModel):
    alert: bool
    reason: str
    severity: str


class AudioAlertResult(BaseModel):
    transcription: str
    alert: bool
    reason: str
    severity: str


def _require_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise ValueError(f"{name} is missing. Set it in your .env file.")
    return value


def _build_openrouter_llm(streaming: bool = False) -> ChatOpenAI:
    return ChatOpenAI(
        base_url=OPENROUTER_BASE_URL,
        api_key=_require_env("OPENROUTER_API_KEY"),
        model=os.getenv("OPENROUTER_CHAT_MODEL", DEFAULT_MODEL),
        temperature=0,
        streaming=streaming,
    )


def _to_data_uri(image_b64: str) -> str:
    clean = image_b64.strip()
    if clean.startswith("data:image"):
        return clean
    return f"data:image/png;base64,{clean}"


def _chunk_frames(frames: Sequence[str], batch_size: int = 10) -> List[List[str]]:
    return [list(frames[i : i + batch_size]) for i in range(0, len(frames), batch_size)]


def _risk_level_from_score(score: int) -> str:
    if score >= 85:
        return "CRITICAL"
    if score >= 65:
        return "HIGH"
    if score >= 40:
        return "MEDIUM"
    return "LOW"


def _severity_weight(severity: str) -> int:
    lookup = {"critical": 35, "high": 20, "medium": 10, "low": 5}
    return lookup.get(severity.lower().strip(), 0)


def _aggregate_batch_reports(batch_reports: Sequence[RiskReportResult]) -> RiskReportResult:
    if not batch_reports:
        raise ValueError("No batch reports were produced.")

    all_flags: List[RedFlagResult] = []
    actions: List[str] = []
    base_scores: List[int] = []

    for report in batch_reports:
        all_flags.extend(report.red_flags)
        base_scores.append(int(report.risk_score))
        for action in report.recommended_actions:
            if action not in actions:
                actions.append(action)

    pattern_counts = Counter(flag.pattern.strip().lower() for flag in all_flags if flag.pattern.strip())
    weighted_flags = sum(_severity_weight(flag.severity) for flag in all_flags)
    consistency_bonus = sum(10 for count in pattern_counts.values() if count >= 3)
    base_score = sum(base_scores) / max(len(base_scores), 1)

    final_score = int(
        min(
            100,
            (base_score * 0.4) + (weighted_flags * 0.5) + (consistency_bonus * 0.1),
        )
    )
    final_level = _risk_level_from_score(final_score)

    top_flags = ", ".join(flag.pattern for flag in all_flags[:3]) if all_flags else "No strong scam indicators"
    summary = f"{final_level} risk based on chat evidence. Top indicators: {top_flags}."

    return RiskReportResult(
        risk_level=final_level,
        risk_score=final_score,
        red_flags=all_flags,
        summary=summary,
        recommended_actions=actions
        or [
            "Do not send money or gift cards",
            "Request additional identity verification",
            "Report suspicious behavior to platform support",
        ],
    )


def _chat_batch_chain():
    llm = _build_openrouter_llm(streaming=False)
    return llm.with_structured_output(RiskReportResult)


def _video_frame_chain():
    llm = _build_openrouter_llm(streaming=False)
    return llm.with_structured_output(VideoAlertResult)


def _audio_alert_chain():
    llm = _build_openrouter_llm(streaming=False)
    return llm.with_structured_output(AudioAlertResult)


def analyze_chat_frames(frames: Sequence[str], platform: str, session_id: str) -> RiskReportResult:
    if not frames:
        raise ValueError("No chat frames provided.")

    chain = _chat_batch_chain()
    reports: List[RiskReportResult] = []

    for batch in _chunk_frames(frames, batch_size=10):
        image_content = [
            {"type": "image_url", "image_url": {"url": _to_data_uri(frame)}}
            for frame in batch
        ]
        messages = [
            SystemMessage(
                content=(
                    "You are a romance scam detection assistant. Analyze provided chat screenshots "
                    "for scam patterns in any language and respond in English. "
                    "Every red flag must include evidence from visible content."
                )
            ),
            HumanMessage(
                content=[
                    {
                        "type": "text",
                        "text": (
                            f"Platform: {platform}. Session: {session_id}. "
                            "Return structured JSON with risk score, flags, summary, and actions."
                        ),
                    },
                    *image_content,
                ]
            ),
        ]
        report = chain.invoke(messages)
        reports.append(report)

    return _aggregate_batch_reports(reports)


def analyze_video_frame(frame: str, session_id: str) -> VideoAlertResult:
    if not frame:
        raise ValueError("Video frame is required.")

    chain = _video_frame_chain()
    messages = [
        SystemMessage(
            content=(
                "You detect visual anomalies in video calls that may indicate romance scams or fake identity. "
                "Return alert, reason, and severity."
            )
        ),
        HumanMessage(
            content=[
                {
                    "type": "text",
                    "text": (
                        f"Session: {session_id}. Check for face inconsistency, blur/loop artifacts, "
                        "and suspicious screen-sharing signals."
                    ),
                },
                {"type": "image_url", "image_url": {"url": _to_data_uri(frame)}},
            ]
        ),
    ]
    return chain.invoke(messages)


def _transcribe_audio(audio_b64: str) -> str:
    if not audio_b64:
        raise ValueError("Audio payload is required.")

    try:
        audio_bytes = base64.b64decode(audio_b64)
    except Exception as exc:  # noqa: BLE001
        raise ValueError("audio_b64 is not valid base64 data.") from exc

    client = OpenAI(api_key=_require_env("OPENAI_API_KEY"))
    stream = io.BytesIO(audio_bytes)
    stream.name = "chunk.wav"
    transcript = client.audio.transcriptions.create(model="whisper-1", file=stream)
    text = getattr(transcript, "text", "").strip()
    if not text:
        raise ValueError("Whisper returned an empty transcription.")
    return text


def analyze_audio_chunk(audio_b64: str, session_id: str) -> AudioAlertResult:
    transcription = _transcribe_audio(audio_b64)
    chain = _audio_alert_chain()
    messages = [
        SystemMessage(
            content=(
                "You detect romance scam indicators in call transcripts. "
                "Watch for money requests, urgency, scripting, and location inconsistencies."
            )
        ),
        HumanMessage(
            content=(
                f"Session: {session_id}. Transcript:\n{transcription}\n"
                "Return structured JSON with alert, reason, severity, and transcription."
            )
        ),
    ]
    result = chain.invoke(messages)
    if not result.transcription:
        result.transcription = transcription
    return result
