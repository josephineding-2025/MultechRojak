"""
Background Check router — Owner: Member 1
Verifies whether a claimed online identity is consistent with public information.
"""
from __future__ import annotations

import asyncio
import json
from typing import List, Optional

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, model_validator
from sse_starlette.sse import EventSourceResponse

from services.osint import run_background_check
from services.osint.bio_parser import parse_bio
from services.scraper import scrape_profile

router = APIRouter(tags=["Background Check"])


# ---------------------------------------------------------------------------
# Request model
# ---------------------------------------------------------------------------

class BackgroundCheckRequest(BaseModel):
    username: str = ""
    platform: str = "Other"
    phone: Optional[str] = None
    photo_b64: Optional[str] = None   # base64-encoded profile image
    profile_url: Optional[str] = None  # primary input — scrapes profile automatically

    @model_validator(mode="after")
    def require_username_or_url(self) -> "BackgroundCheckRequest":
        if not self.username.strip() and not self.profile_url:
            raise ValueError("Either 'username' or 'profile_url' must be provided.")
        return self


# ---------------------------------------------------------------------------
# Response models
# ---------------------------------------------------------------------------

class DossierFinding(BaseModel):
    category: str    # 'photo' | 'phone' | 'account' | 'username'
    severity: str    # 'critical' | 'high' | 'medium' | 'low'
    flag: str
    evidence: str


class ScrapedProfile(BaseModel):
    platform: Optional[str] = None
    username: Optional[str] = None
    bio_text: Optional[str] = None
    follower_count: Optional[int] = None
    following_count: Optional[int] = None
    account_age_days: Optional[int] = None
    post_count: Optional[int] = None
    scrape_error: Optional[str] = None
    raw_url: Optional[str] = None


class DiscoveredIdentifiers(BaseModel):
    phones: List[str] = []
    emails: List[str] = []
    handles: List[str] = []
    location_claim: Optional[str] = None
    occupation_claim: Optional[str] = None


class BackgroundCheckResult(BaseModel):
    # --- Existing 13 fields (unchanged for backward compat) ---
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
    photo_hash: Optional[str] = None
    # --- 5 new dossier fields ---
    confidence_score: Optional[int] = None
    risk_level: Optional[str] = None
    scraped_profile: Optional[ScrapedProfile] = None
    discovered_identifiers: Optional[DiscoveredIdentifiers] = None
    findings: List[DossierFinding] = []


# ---------------------------------------------------------------------------
# SSE event model
# ---------------------------------------------------------------------------

class BackgroundCheckEvent(BaseModel):
    step: str     # 'scraping' | 'parsing_bio' | 'osint' | 'complete' | 'error'
    status: str   # 'started' | 'done' | 'failed'
    message: str
    severity: Optional[str] = None
    result: Optional[BackgroundCheckResult] = None


# ---------------------------------------------------------------------------
# Shared orchestration helper
# ---------------------------------------------------------------------------

async def _run_full_check(
    profile_url: Optional[str],
    username: str,
    platform: str,
    phone: Optional[str],
    photo_b64: Optional[str],
) -> dict:
    """Orchestrate scrape → bio parse → OSINT. Returns raw result dict."""
    scraped_data: Optional[dict] = None

    if profile_url:
        scraped_data = await scrape_profile(profile_url)
        bio_text = scraped_data.get("bio_text") or ""
        parsed_bio = parse_bio(bio_text)
        scraped_data["parsed_bio"] = parsed_bio

        effective_username = username.strip() or scraped_data.get("username", "")
        effective_platform = platform if platform != "Other" else (
            scraped_data.get("platform") or "Other"
        )
    else:
        effective_username = username
        effective_platform = platform

    # run_background_check is synchronous — offload to thread pool
    result_dict = await asyncio.get_event_loop().run_in_executor(
        None,
        lambda: run_background_check(
            username=effective_username,
            platform=effective_platform,
            phone=phone,
            photo_b64=photo_b64,
            scraped_data=scraped_data,
        ),
    )
    return result_dict


# ---------------------------------------------------------------------------
# POST /background-check  (standard request-response)
# ---------------------------------------------------------------------------

@router.post("/background-check", response_model=BackgroundCheckResult)
async def background_check(req: BackgroundCheckRequest) -> BackgroundCheckResult:
    """Run a full background check. Accepts a profile URL or manual fields."""
    try:
        result_dict = await _run_full_check(
            profile_url=req.profile_url,
            username=req.username,
            platform=req.platform,
            phone=req.phone,
            photo_b64=req.photo_b64,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail="Background check failed") from exc

    # Coerce nested dicts into Pydantic models
    return _dict_to_result(result_dict)


# ---------------------------------------------------------------------------
# GET /background-check/stream  (SSE streaming)
# ---------------------------------------------------------------------------

@router.get("/background-check/stream")
async def background_check_stream(
    request: Request,
    profile_url: str,
    username: str = "",
    platform: str = "Other",
    phone: Optional[str] = None,
) -> EventSourceResponse:
    """Stream background check progress via Server-Sent Events."""

    async def event_generator():
        try:
            # Step 1: scrape profile
            yield _sse(BackgroundCheckEvent(
                step="scraping", status="started",
                message="Fetching profile page...",
            ))
            scraped_data = await scrape_profile(profile_url)
            scrape_err = scraped_data.get("scrape_error")
            scrape_username = scraped_data.get("username", "")
            if scrape_err:
                yield _sse(BackgroundCheckEvent(
                    step="scraping", status="done",
                    message=f"Scrape partial — fell back to URL-extracted username @{scrape_username}. ({scrape_err[:80]})",
                ))
            else:
                yield _sse(BackgroundCheckEvent(
                    step="scraping", status="done",
                    message=f"Profile scraped: @{scrape_username} — "
                            f"{scraped_data.get('follower_count', '?')} followers",
                ))

            # Step 2: parse bio
            yield _sse(BackgroundCheckEvent(
                step="parsing_bio", status="started",
                message="Extracting identifiers from bio...",
            ))
            bio_text = scraped_data.get("bio_text") or ""
            parsed_bio = parse_bio(bio_text)
            scraped_data["parsed_bio"] = parsed_bio

            phones_found = len(parsed_bio.get("phone_numbers") or [])
            handles_found = len(parsed_bio.get("linked_handles") or [])
            yield _sse(BackgroundCheckEvent(
                step="parsing_bio", status="done",
                message=f"Bio parsed — found {phones_found} phone(s), {handles_found} linked handle(s)",
            ))

            # Step 3: OSINT checks
            yield _sse(BackgroundCheckEvent(
                step="osint", status="started",
                message="Running OSINT checks (Sherlock, reverse image search, phone validation)...",
            ))
            effective_username = username.strip() or scraped_data.get("username", "")
            effective_platform = platform if platform != "Other" else (
                scraped_data.get("platform") or "Other"
            )
            result_dict = await asyncio.get_event_loop().run_in_executor(
                None,
                lambda: run_background_check(
                    username=effective_username,
                    platform=effective_platform,
                    phone=phone,
                    photo_b64=None,
                    scraped_data=scraped_data,
                ),
            )

            # Emit finding summaries
            for finding in result_dict.get("findings", []):
                yield _sse(BackgroundCheckEvent(
                    step="osint", status="done",
                    message=finding["flag"],
                    severity=finding["severity"],
                ))

            # Final complete event
            result = _dict_to_result(result_dict)
            yield _sse(BackgroundCheckEvent(
                step="complete", status="done",
                message=f"Background check complete — score: {result.confidence_score}/100 ({result.risk_level} risk)",
                result=result,
            ))

        except Exception as exc:
            yield _sse(BackgroundCheckEvent(
                step="error", status="failed",
                message=str(exc),
                severity="high",
            ))

    return EventSourceResponse(event_generator())


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _sse(event: BackgroundCheckEvent) -> dict:
    """Serialize a BackgroundCheckEvent as an SSE data dict."""
    return {"data": event.model_dump_json()}


def _dict_to_result(d: dict) -> BackgroundCheckResult:
    """Convert the raw run_background_check() return dict to BackgroundCheckResult."""
    scraped_raw = d.get("scraped_profile")
    discovered_raw = d.get("discovered_identifiers")
    findings_raw = d.get("findings") or []

    return BackgroundCheckResult(
        photo_found_online=d["photo_found_online"],
        photo_sources=d["photo_sources"],
        username_platforms=d["username_platforms"],
        phone_valid=d["phone_valid"],
        phone_country=d["phone_country"],
        phone_carrier=d.get("phone_carrier"),
        profile_consistency_score=d["profile_consistency_score"],
        background_summary=d["background_summary"],
        platform_verified=d["platform_verified"],
        platform_followers=d.get("platform_followers"),
        platform_account_age_days=d.get("platform_account_age_days"),
        authenticity_note=d["authenticity_note"],
        photo_hash=d.get("photo_hash"),
        confidence_score=d.get("confidence_score"),
        risk_level=d.get("risk_level"),
        scraped_profile=ScrapedProfile(**{
            k: scraped_raw.get(k) for k in ScrapedProfile.model_fields
        }) if scraped_raw else None,
        discovered_identifiers=DiscoveredIdentifiers(**{
            k: discovered_raw.get(k) for k in DiscoveredIdentifiers.model_fields
        }) if discovered_raw else None,
        findings=[DossierFinding(**f) for f in findings_raw],
    )
