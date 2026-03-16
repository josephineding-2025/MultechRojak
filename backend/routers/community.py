"""
Community Flagging router — Owner: Member 3
Allows users to report scammers and warn others via a shared community database.
"""
from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Optional

router = APIRouter(tags=["Community Flagging"])


class FlagScammerRequest(BaseModel):
    platform: str
    handle: str
    phone: Optional[str] = None
    photo_hash: Optional[str] = None
    flags: List[str]
    region: str


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

    TODO (Member 3): Replace mock with real Supabase upsert.
    See backend/services/flagging/ for the implementation stub.
    """
    # --- MOCK RESPONSE — matches SPEC.md Section 8 exactly ---
    return FlagScammerResult(
        success=True,
        profile_status="flagged",
        total_reports=8,
    )


@router.get("/check-profile", response_model=ProfileCheckResult)
async def check_profile(
    handle: Optional[str] = None,
    phone: Optional[str] = None,
    photo_hash: Optional[str] = None,
) -> ProfileCheckResult:
    """
    Check if a profile matches any community-flagged entries.

    TODO (Member 3): Replace mock with real Supabase query + fuzzy matching.
    See backend/services/flagging/ for the implementation stub.
    """
    # --- MOCK RESPONSE — matches SPEC.md Section 8 exactly ---
    return ProfileCheckResult(
        flagged=True,
        status="flagged",
        report_count=7,
        first_reported="2026-01-12",
        common_flags=["money request", "fake investment"],
        region="MY",
    )
