"""
Background Check router — Owner: Member 1
Verifies whether a claimed online identity is consistent with public information.
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional

from services.osint import run_background_check

router = APIRouter(tags=["Background Check"])


class BackgroundCheckRequest(BaseModel):
    username: str
    platform: str
    phone: Optional[str] = None
    photo_b64: Optional[str] = None  # base64-encoded profile image


class BackgroundCheckResult(BaseModel):
    photo_found_online: bool
    photo_sources: List[str]
    username_platforms: List[str]
    phone_valid: bool
    phone_country: str
    phone_carrier: Optional[str] = None
    profile_consistency_score: int   # 0–100 (lower = more suspicious)
    background_summary: str
    platform_verified: bool
    platform_followers: Optional[int] = None
    platform_account_age_days: Optional[int] = None
    authenticity_note: str
    photo_hash: Optional[str] = None   # perceptual hash; null if no photo provided


@router.post("/background-check", response_model=BackgroundCheckResult)
async def background_check(req: BackgroundCheckRequest) -> BackgroundCheckResult:
    """Run a background check on a profile using OSINT tools."""
    try:
        result = run_background_check(
            username=req.username,
            platform=req.platform,
            phone=req.phone,
            photo_b64=req.photo_b64,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Background check failed") from exc
    return BackgroundCheckResult(**result)
