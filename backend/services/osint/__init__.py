"""OSINT pipeline for background checks."""

from __future__ import annotations

import os
from base64 import b64decode
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from io import BytesIO
from typing import Optional

import imagehash
import requests
from PIL import Image
from sherlock_project.sherlock import sherlock as _sherlock_search
from sherlock_project.sites import SitesInformation
from sherlock_project.notify import QueryNotify
from sherlock_project.result import QueryStatus


def _require_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise ValueError(f"{name} is missing. Set it in your .env file.")
    return value


def _decode_base64_payload(payload: str) -> bytes:
    if not payload or not payload.strip():
        raise ValueError("payload must not be empty")

    clean = payload.strip()
    if "," in clean and clean.lower().startswith("data:"):
        clean = clean.split(",", 1)[1]

    try:
        return b64decode(clean, validate=True)
    except Exception as exc:  # noqa: BLE001
        raise ValueError("Invalid base64 payload.") from exc


def validate_phone(phone: str) -> dict:
    if not phone or not phone.strip():
        raise ValueError("phone must not be empty")
    key = _require_env("NUMVERIFY_API_KEY")
    resp = requests.get(
        "https://apilayer.net/api/validate",
        params={"access_key": key, "number": phone},
        timeout=10,
    )
    data = resp.json()
    if data.get("error"):
        raise RuntimeError(f"NumVerify error: {data['error']}")
    return {
        "valid": bool(data.get("valid")),
        "country_name": data.get("country_name") or "",
        "carrier": data.get("carrier") or None,
    }


class _SilentNotify(QueryNotify):
    def start(self, message): pass
    def update(self, result): pass
    def finish(self): return 0


_SHERLOCK_SITES: dict | None = None


def _get_sherlock_sites() -> dict:
    global _SHERLOCK_SITES
    if _SHERLOCK_SITES is None:
        sites = SitesInformation()
        _SHERLOCK_SITES = {site.name: site.information for site in sites}
    return _SHERLOCK_SITES


def check_username_platforms(username: str) -> list[str]:
    """Check username across 400+ platforms via Sherlock."""
    site_data = _get_sherlock_sites()
    results = _sherlock_search(
        username,
        site_data=site_data,
        query_notify=_SilentNotify(),
        timeout=10,
    )
    return [
        site_name
        for site_name, result in results.items()
        if result["status"].status == QueryStatus.CLAIMED
    ]


def compute_phash(photo_b64: str) -> str:
    try:
        img = Image.open(BytesIO(_decode_base64_payload(photo_b64)))
        return str(imagehash.phash(img))
    except Exception as exc:
        raise ValueError(f"Failed to compute phash: {exc}") from exc


def reverse_image_search(photo_b64: str) -> list[str]:
    key = _require_env("SERPAPI_KEY")
    photo_bytes = _decode_base64_payload(photo_b64)
    resp = requests.post(
        "https://serpapi.com/search",
        params={"engine": "google_reverse_image", "api_key": key},
        files={"image_file": ("photo.jpg", photo_bytes, "image/jpeg")},
        timeout=30,
    )
    if resp.status_code != 200:
        raise RuntimeError(f"SerpAPI returned {resp.status_code}: {resp.text[:200]}")
    data = resp.json()
    raw = data.get("inline_images") or data.get("image_results") or []
    urls: list[str] = []
    seen: set[str] = set()
    for item in raw:
        url = item.get("link") or item.get("original") or (item if isinstance(item, str) else None)
        if url and url not in seen:
            seen.add(url)
            urls.append(url)
        if len(urls) >= 10:
            break
    return urls


def _build_authenticity_note(is_verified: bool, followers: int, age_days: int, platform: str) -> str:
    if is_verified and followers > 100_000 and age_days > 365:
        return "High confidence: matches signals of a real public figure account."
    if not is_verified and age_days < 90:
        return "Warning: new unverified account. Could be impersonation."
    if is_verified and followers <= 100_000:
        return "Verified but low engagement. Verify independently."
    return "Account exists but lacks strong authenticity signals. Verify independently."


def _safe_call(func, *args, default=None, swallow=(Exception,)):
    try:
        return func(*args)
    except swallow:
        return default


def check_platform_authenticity(username: str, platform: str) -> dict:
    """Deep authenticity check on the claimed platform. Supports X and GitHub."""
    p = platform.strip().lower()

    if p not in ("x", "twitter", "github"):
        return {
            "platform_verified": False,
            "platform_followers": None,
            "platform_account_age_days": None,
            "authenticity_note": f"Manual verification recommended for {platform}.",
        }

    if p == "github":
        try:
            resp = requests.get(
                f"https://api.github.com/users/{username}",
                headers={"Accept": "application/vnd.github+json"},
                timeout=10,
            )
            if resp.status_code == 404:
                return {"platform_verified": False, "platform_followers": None,
                        "platform_account_age_days": None,
                        "authenticity_note": f"GitHub account '{username}' does not exist."}
            resp.raise_for_status()
            data = resp.json()
            followers = data.get("followers", 0)
            age_days = (datetime.now(timezone.utc) -
                        datetime.fromisoformat(data["created_at"].replace("Z", "+00:00"))).days
            return {"platform_verified": False, "platform_followers": followers,
                    "platform_account_age_days": age_days,
                    "authenticity_note": _build_authenticity_note(False, followers, age_days, platform)}
        except Exception:
            return {"platform_verified": False, "platform_followers": None,
                    "platform_account_age_days": None,
                    "authenticity_note": "GitHub check failed. Verify manually."}

    # X / Twitter
    bearer_token = os.getenv("X_BEARER_TOKEN", "")
    if not bearer_token:
        return {"platform_verified": False, "platform_followers": None,
                "platform_account_age_days": None,
                "authenticity_note": "X check unavailable: API token not configured."}
    try:
        resp = requests.get(
            f"https://api.twitter.com/2/users/by/username/{username}",
            params={"user.fields": "verified,public_metrics,created_at"},
            headers={"Authorization": f"Bearer {bearer_token}"},
            timeout=10,
        )
        if resp.status_code == 429:
            return {"platform_verified": False, "platform_followers": None,
                    "platform_account_age_days": None,
                    "authenticity_note": "X rate limit reached. Try again later."}
        resp.raise_for_status()
        body = resp.json()
        if "errors" in body and "data" not in body:
            return {"platform_verified": False, "platform_followers": None,
                    "platform_account_age_days": None,
                    "authenticity_note": f"X account '{username}' not found."}
        user = body["data"]
        is_verified = bool(user.get("verified", False))
        followers = user.get("public_metrics", {}).get("followers_count", 0)
        age_days = (datetime.now(timezone.utc) -
                    datetime.fromisoformat(user["created_at"].replace("Z", "+00:00"))).days
        return {"platform_verified": is_verified, "platform_followers": followers,
                "platform_account_age_days": age_days,
                "authenticity_note": _build_authenticity_note(is_verified, followers, age_days, platform)}
    except Exception:
        return {"platform_verified": False, "platform_followers": None,
                "platform_account_age_days": None,
                "authenticity_note": "X check failed. Verify manually."}


def run_background_check(
    username: str,
    platform: str,
    phone: Optional[str] = None,
    photo_b64: Optional[str] = None,
    scraped_data: Optional[dict] = None,
) -> dict:
    # --- Merge scraped data with manual inputs ---
    effective_photo_b64 = photo_b64
    effective_phone = phone
    discovered_identifiers: Optional[dict] = None

    if scraped_data:
        if not effective_photo_b64 and scraped_data.get("photo_b64"):
            effective_photo_b64 = scraped_data["photo_b64"]
        bio = (scraped_data.get("parsed_bio") or {})
        bio_phones = bio.get("phone_numbers") or []
        if not effective_phone and bio_phones:
            effective_phone = bio_phones[0]
        discovered_identifiers = {
            "phones": bio_phones,
            "emails": bio.get("emails") or [],
            "handles": bio.get("linked_handles") or [],
            "location_claim": bio.get("location_claim"),
            "occupation_claim": bio.get("occupation_claim"),
        }

    if not username or not username.strip():
        raise ValueError("username must not be empty")
    if not platform or not platform.strip():
        raise ValueError("platform must not be empty")
    if photo_b64 and photo_b64.strip():
        _decode_base64_payload(photo_b64)

    # --- Parallel OSINT fan-out ---
    with ThreadPoolExecutor(max_workers=4) as executor:
        username_future = executor.submit(check_username_platforms, username.strip())
        authenticity_future = executor.submit(
            check_platform_authenticity,
            username.strip(),
            platform,
        )
        phone_future = (
            executor.submit(validate_phone, effective_phone.strip())
            if effective_phone and effective_phone.strip()
            else None
        )
        reverse_image_future = (
            executor.submit(reverse_image_search, effective_photo_b64)
            if effective_photo_b64 and effective_photo_b64.strip()
            else None
        )
        photo_hash_future = (
            executor.submit(compute_phash, effective_photo_b64)
            if effective_photo_b64 and effective_photo_b64.strip()
            else None
        )

        username_platforms = _safe_call(username_future.result, default=[], swallow=(Exception,))
        authenticity = _safe_call(
            authenticity_future.result,
            default={
                "platform_verified": False,
                "platform_followers": None,
                "platform_account_age_days": None,
                "authenticity_note": f"Manual verification recommended for {platform}.",
            },
            swallow=(Exception,),
        )

        phone_valid = False
        phone_country = ""
        phone_carrier: Optional[str] = None
        if phone_future is not None:
            phone_result = _safe_call(
                phone_future.result,
                default=None,
                swallow=(Exception,),
            )
            if phone_result:
                phone_valid = phone_result["valid"]
                phone_country = phone_result["country_name"]
                phone_carrier = phone_result["carrier"]

        photo_sources = []
        if reverse_image_future is not None:
            photo_sources = _safe_call(
                reverse_image_future.result,
                default=[],
                swallow=(Exception,),
            ) or []
        photo_found_online = len(photo_sources) > 0

        photo_hash: Optional[str] = None
        if photo_hash_future is not None:
            photo_hash = _safe_call(
                photo_hash_future.result,
                default=None,
                swallow=(Exception,),
            )

    # --- Consistency score (proportional to checks that ran) ---
    WEIGHT_USERNAME = 40
    WEIGHT_PHONE    = 30
    WEIGHT_PHOTO    = 30

    total_possible   = WEIGHT_USERNAME
    total_deductions = 0

    # Username: 50+ platforms = bot/famous-name signal → full deduction
    if len(username_platforms) >= 50:
        total_deductions += WEIGHT_USERNAME

    # Phone: only counts if provided
    if effective_phone and effective_phone.strip():
        total_possible += WEIGHT_PHONE
        if not phone_valid:
            total_deductions += WEIGHT_PHONE

    # Photo: only counts if provided
    if effective_photo_b64 and effective_photo_b64.strip():
        total_possible += WEIGHT_PHOTO
        if photo_found_online:
            extra = len(photo_sources) - 1
            photo_deduction = 15 + min(extra * 5, 15)  # 15 base + up to 15 more
            total_deductions += min(photo_deduction, WEIGHT_PHOTO)

    # --- Account velocity scoring (from scraped data) ---
    follower_velocity_flag = False
    daily_follower_rate: Optional[float] = None
    if scraped_data:
        follower_count = scraped_data.get("follower_count")
        account_age_days = scraped_data.get("account_age_days")
        if follower_count is not None and account_age_days is not None and account_age_days > 0:
            daily_follower_rate = follower_count / account_age_days
            if daily_follower_rate > 100:
                follower_velocity_flag = True
                total_possible += 10
                total_deductions += 10

    score = round(((total_possible - total_deductions) / total_possible) * 100)
    score = max(0, min(100, score))

    # --- Risk level ---
    if score >= 70:
        risk_level = "LOW"
    elif score >= 40:
        risk_level = "MEDIUM"
    elif score >= 20:
        risk_level = "HIGH"
    else:
        risk_level = "CRITICAL"

    # --- Findings list ---
    findings: list[dict] = []

    if photo_found_online:
        severity = "critical" if len(photo_sources) > 2 else "high"
        findings.append({
            "category": "photo",
            "severity": severity,
            "flag": f"Profile photo found on {len(photo_sources)} external site(s)",
            "evidence": f"Sources: {', '.join(photo_sources[:3])}",
        })

    if effective_phone and effective_phone.strip() and not phone_valid:
        findings.append({
            "category": "phone",
            "severity": "medium",
            "flag": "Phone number is invalid or unverified",
            "evidence": f"NumVerify returned invalid for {effective_phone}",
        })

    if effective_phone and phone_valid and phone_country:
        location_claim = (discovered_identifiers or {}).get("location_claim") or ""
        if location_claim and phone_country.lower() not in location_claim.lower():
            findings.append({
                "category": "phone",
                "severity": "high",
                "flag": f"Phone country mismatch — registered in {phone_country}",
                "evidence": f"Claimed location: '{location_claim}', phone country: '{phone_country}'",
            })

    if follower_velocity_flag and daily_follower_rate is not None:
        findings.append({
            "category": "account",
            "severity": "medium",
            "flag": "Suspicious follower growth velocity",
            "evidence": f"{daily_follower_rate:.0f} followers/day — consistent with purchased followers",
        })

    if len(username_platforms) == 0:
        findings.append({
            "category": "username",
            "severity": "low",
            "flag": "No platform presence found for this username",
            "evidence": "Sherlock search returned no matches across 400+ platforms",
        })
    elif len(username_platforms) >= 50:
        findings.append({
            "category": "username",
            "severity": "high",
            "flag": f"Username found on {len(username_platforms)} platforms — possible bot or impersonation",
            "evidence": f"Sample platforms: {', '.join(username_platforms[:5])}",
        })

    # --- Summary ---
    parts: list[str] = []
    if photo_found_online:
        parts.append(f"Profile photo found on {len(photo_sources)} source(s).")
    else:
        parts.append("No profile photo matches found online.")
    if effective_phone and effective_phone.strip():
        if phone_valid:
            parts.append(f"Phone valid, registered in {phone_country} via {phone_carrier or 'unknown carrier'}.")
        else:
            parts.append("Phone number is invalid or unverified.")
    if username_platforms:
        parts.append(f"Username found on: {', '.join(username_platforms)}.")
    else:
        parts.append("Username not found on checked platforms.")
    if risk_level in {"HIGH", "CRITICAL"}:
        parts.append(f"{risk_level} RISK: Multiple suspicious indicators detected.")

    return {
        "photo_found_online": photo_found_online,
        "photo_sources": photo_sources,
        "username_platforms": username_platforms,
        "phone_valid": phone_valid,
        "phone_country": phone_country,
        "phone_carrier": phone_carrier,
        "profile_consistency_score": score,
        "background_summary": " ".join(parts),
        "platform_verified": authenticity["platform_verified"],
        "platform_followers": authenticity["platform_followers"],
        "platform_account_age_days": authenticity["platform_account_age_days"],
        "authenticity_note": authenticity["authenticity_note"],
        "photo_hash": photo_hash,
        # --- New dossier fields ---
        "confidence_score": score,
        "risk_level": risk_level,
        "scraped_profile": scraped_data,
        "discovered_identifiers": discovered_identifiers,
        "findings": findings,
    }
