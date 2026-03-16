"""
Background Check router — Owner: Member 1
Verifies whether a claimed online identity is consistent with public information.
"""
from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Optional

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


@router.post("/background-check", response_model=BackgroundCheckResult)
async def background_check(req: BackgroundCheckRequest) -> BackgroundCheckResult:
    """
    Run a background check on a profile using OSINT tools.

    TODO (Member 1): Replace mock with real pipeline:
      - Reverse image search via SerpAPI
      - Username check via Sherlock
      - Phone validation via NumVerify
      - Social consistency via Social Analyzer
    See backend/services/osint/ for the implementation stub.
    """
    # --- MOCK RESPONSE — matches SPEC.md Section 8 exactly ---
    return BackgroundCheckResult(
        photo_found_online=True,
        photo_sources=["instagram.com/user123"],
        username_platforms=["Telegram", "Reddit"],
        phone_valid=True,
        phone_country="Nigeria",
        phone_carrier="MTN",
        profile_consistency_score=32,
        background_summary=(
            "Profile photo found on 2 unrelated accounts. "
            "Phone number registered in a different country than claimed."
        ),
    )
