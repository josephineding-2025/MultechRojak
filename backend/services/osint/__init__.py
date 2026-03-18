"""OSINT pipeline for background checks."""

from __future__ import annotations

import os
from base64 import b64decode
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


def validate_phone(phone: str) -> dict:
    if not phone or not phone.strip():
        raise ValueError("phone must not be empty")
    key = _require_env("NUMVERIFY_API_KEY")
    resp = requests.get(
        "http://apilayer.net/api/validate",
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
        img = Image.open(BytesIO(b64decode(photo_b64)))
        return str(imagehash.phash(img))
    except Exception as exc:
        raise ValueError(f"Failed to compute phash: {exc}") from exc


def reverse_image_search(photo_b64: str) -> list[str]:
    key = _require_env("SERPAPI_KEY")
    resp = requests.post(
        "https://serpapi.com/search",
        params={"engine": "google_reverse_image", "api_key": key},
        files={"image_file": ("photo.jpg", b64decode(photo_b64), "image/jpeg")},
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
) -> dict:
    if not username or not username.strip():
        raise ValueError("username must not be empty")

    # --- Username platforms ---
    username_platforms = check_username_platforms(username.strip())

    # --- Phone validation ---
    phone_valid = False
    phone_country = ""
    phone_carrier: Optional[str] = None
    if phone and phone.strip():
        try:
            phone_result = validate_phone(phone.strip())
            phone_valid = phone_result["valid"]
            phone_country = phone_result["country_name"]
            phone_carrier = phone_result["carrier"]
        except (RuntimeError, ValueError):
            pass

    # --- Photo / reverse image search ---
    photo_found_online = False
    photo_sources: list[str] = []
    if photo_b64 and photo_b64.strip():
        try:
            photo_sources = reverse_image_search(photo_b64)
            photo_found_online = len(photo_sources) > 0
        except (RuntimeError, ValueError):
            pass

    # --- Platform authenticity ---
    authenticity = check_platform_authenticity(username.strip(), platform)

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
    if phone and phone.strip():
        total_possible += WEIGHT_PHONE
        if not phone_valid:
            total_deductions += WEIGHT_PHONE

    # Photo: only counts if provided
    if photo_b64 and photo_b64.strip():
        total_possible += WEIGHT_PHOTO
        if photo_found_online:
            extra = len(photo_sources) - 1
            photo_deduction = 15 + min(extra * 5, 15)  # 15 base + up to 15 more
            total_deductions += min(photo_deduction, WEIGHT_PHOTO)

    score = round(((total_possible - total_deductions) / total_possible) * 100)
    score = max(0, min(100, score))

    # --- Summary ---
    parts: list[str] = []
    if photo_found_online:
        parts.append(f"Profile photo found on {len(photo_sources)} source(s).")
    else:
        parts.append("No profile photo matches found online.")
    if phone and phone.strip():
        if phone_valid:
            parts.append(f"Phone valid, registered in {phone_country} via {phone_carrier or 'unknown carrier'}.")
        else:
            parts.append("Phone number is invalid or unverified.")
    if username_platforms:
        parts.append(f"Username found on: {', '.join(username_platforms)}.")
    else:
        parts.append("Username not found on checked platforms.")
    if score < 50:
        parts.append("HIGH RISK: Multiple suspicious indicators detected.")

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
    }
