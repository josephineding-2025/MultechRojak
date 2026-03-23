"""
Community Flagging router — Owner: Member 3
Allows users to report scammers and warn others via a shared community database.
"""
import logging
from typing import List, Optional

from fastapi import APIRouter, HTTPException
import httpx
from pydantic import BaseModel

from services.flagging import check_profile as check_profile_service
from services.flagging import submit_scammer_report

router = APIRouter(tags=["Community Flagging"])
logger = logging.getLogger(__name__)


def _detail_for_community_error(exc: Exception) -> str:
    if isinstance(exc, httpx.HTTPError):
        return "Supabase is unreachable. Check SUPABASE_URL, network access, and project availability."

    message = str(exc).strip()
    if message:
        return message
    return "Community database request failed."


class FlagScammerRequest(BaseModel):
    platform: str
    handle: Optional[str] = None
    phone: Optional[str] = None
    photo_hash: Optional[str] = None
    flags: List[str]
    region: str
    source_type: str
    source_risk_level: str
    source_session_id: str


class FlagScammerResult(BaseModel):
    success: bool
    profile_status: str    # "reported" | "flagged" | "confirmed"
    total_reports: int


class ProfileCheckResult(BaseModel):
    flagged: bool
    status: Optional[str] = None       # "reported" | "flagged" | "confirmed"
    report_count: Optional[int] = None
    first_reported: Optional[str] = None
    common_flags: Optional[List[str]] = None
    region: Optional[str] = None


@router.post("/flag-scammer", response_model=FlagScammerResult)
async def flag_scammer(req: FlagScammerRequest) -> FlagScammerResult:
    """
    Submit a community flag for a scammer profile.
    """
    if req.source_risk_level.upper() not in {"LOW", "MEDIUM", "HIGH", "CRITICAL"}:
        raise HTTPException(
            status_code=400,
            detail="Community reporting is only allowed after a completed scan.",
        )
    if not req.source_session_id.strip():
        raise HTTPException(
            status_code=400,
            detail="source_session_id is required for gated community reports",
        )

    try:
        result = submit_scammer_report(
            platform=req.platform,
            handle=req.handle,
            phone=req.phone,
            photo_hash=req.photo_hash,
            flags=req.flags,
            region=req.region,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        logger.exception("Community flag submission failed")
        raise HTTPException(
            status_code=500,
            detail=_detail_for_community_error(exc),
        ) from exc

    return FlagScammerResult(**result)


@router.get("/check-profile", response_model=ProfileCheckResult)
async def check_profile(
    handle: Optional[str] = None,
    phone: Optional[str] = None,
    photo_hash: Optional[str] = None,
) -> ProfileCheckResult:
    """
    Check if a profile matches any community-flagged entries.
    """
    if not any([handle and handle.strip(), phone and phone.strip(), photo_hash and photo_hash.strip()]):
        raise HTTPException(status_code=400, detail="At least one of handle, phone, or photo_hash is required")

    try:
        result = check_profile_service(
            handle=handle,
            phone=phone,
            photo_hash=photo_hash,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        logger.exception("Community profile check failed")
        raise HTTPException(
            status_code=500,
            detail=_detail_for_community_error(exc),
        ) from exc

    return ProfileCheckResult(**result)
