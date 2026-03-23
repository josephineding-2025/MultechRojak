"""
Community Flagging Service — Owner: Member 3

This package contains the Supabase integration for community flagging:
  - Submit scammer reports (upsert by handle/phone/photo_hash)
  - Query community database (exact + fuzzy match)
  - Compute confidence tier from report count
  - Perceptual hash comparison for photo matching

Implementation steps:
  1. Initialize Supabase client using SUPABASE_URL and SUPABASE_ANON_KEY from .env
  2. Implement upsert logic for scammer profiles
  3. Add fuzzy matching for username lookup (handle variations like john88 vs j0hn88)
  4. Add pHash comparison for profile picture matching
  5. Map report_count to confidence tier (1-2: reported, 3-9: flagged, 10+: confirmed)

See docs/SPEC.md Section 4.4 for the full community flagging spec.
"""

from __future__ import annotations

import os
from datetime import date
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any, Iterable, Optional

from dotenv import load_dotenv
from supabase import Client, create_client

try:
    from rapidfuzz import fuzz as _fuzz
except ImportError:
    try:
        from fuzzywuzzy import fuzz as _fuzz
    except ImportError:
        _fuzz = None

TABLE_NAME = "scammer_profiles"
PHASH_DISTANCE_THRESHOLD = 10
HANDLE_FUZZY_MATCH_THRESHOLD = 78

_SUPABASE_CLIENT: Client | None = None

BASE_DIR = Path(__file__).resolve().parents[2]
ENV_PATH = BASE_DIR / ".env"

load_dotenv(dotenv_path=ENV_PATH)


def _require_env(name: str) -> str:
    value = os.getenv(name)
    if value is None or not value.strip():
        env_hint = f" at {ENV_PATH}" if ENV_PATH.exists() else f" at {ENV_PATH} (file not found)"
        raise ValueError(f"{name} is missing. Set it in your .env file{env_hint}.")
    return value


def _get_supabase_config() -> tuple[str, str]:
    raw_url = os.getenv("SUPABASE_URL")
    if raw_url is None:
        env_hint = f" at {ENV_PATH}" if ENV_PATH.exists() else f" at {ENV_PATH} (file not found)"
        raise ValueError(f"SUPABASE_URL is missing. Set it in your .env file{env_hint}.")

    url = raw_url.strip()
    if not url:
        raise ValueError("SUPABASE_URL is empty. Set it in your .env file.")

    anon_key = _require_env("SUPABASE_ANON_KEY").strip()

    if not url.startswith("https://"):
        raise ValueError(
            "SUPABASE_URL is invalid. Set it in your .env file and ensure it starts with https://"
        )

    if not anon_key:
        raise ValueError("SUPABASE_ANON_KEY is missing. Set it in your .env file.")

    return url, anon_key


def get_supabase_client() -> Client:
    """
    1. Initialize Supabase client using SUPABASE_URL and SUPABASE_ANON_KEY from .env
    """
    global _SUPABASE_CLIENT
    if _SUPABASE_CLIENT is None:
        url, anon_key = _get_supabase_config()
        _SUPABASE_CLIENT = create_client(url, anon_key)
    return _SUPABASE_CLIENT


def _clean_handle(handle: Optional[str]) -> Optional[str]:
    if handle is None:
        return None
    cleaned = handle.strip()
    return cleaned or None


def normalize_handle(handle: Optional[str]) -> Optional[str]:
    """
    3. Add fuzzy matching for username lookup (handle variations like john88 vs j0hn88)
    """
    cleaned = _clean_handle(handle)
    if cleaned is None:
        return None

    translation = str.maketrans(
        {
            "@": "",
            "0": "o",
            "1": "l",
            "3": "e",
            "5": "s",
            "7": "t",
            "_": "",
            ".": "",
            "-": "",
            " ": "",
        }
    )
    return cleaned.lower().translate(translation)


def _clean_phone(phone: Optional[str]) -> Optional[str]:
    if phone is None:
        return None
    digits = "".join(ch for ch in phone if ch.isdigit() or ch == "+").strip()
    return digits or None


def _clean_photo_hash(photo_hash: Optional[str]) -> Optional[str]:
    if photo_hash is None:
        return None
    cleaned = photo_hash.strip().lower()
    return cleaned or None


def _dedupe_flags(flags: Optional[Iterable[str]]) -> list[str]:
    deduped: list[str] = []
    seen: set[str] = set()
    for flag in flags or []:
        cleaned = flag.strip()
        key = cleaned.lower()
        if cleaned and key not in seen:
            seen.add(key)
            deduped.append(cleaned)
    return deduped


def status_from_report_count(report_count: int) -> str:
    """
    5. Map report_count to confidence tier (1-2: reported, 3-9: flagged, 10+: confirmed)
    """
    if report_count >= 10:
        return "confirmed"
    if report_count >= 3:
        return "flagged"
    return "reported"


def phash_distance(left_hash: Optional[str], right_hash: Optional[str]) -> Optional[int]:
    """
    4. Add pHash comparison for profile picture matching
    """
    left = _clean_photo_hash(left_hash)
    right = _clean_photo_hash(right_hash)
    if not left or not right:
        return None

    max_len = max(len(left), len(right))
    left = left.zfill(max_len)
    right = right.zfill(max_len)

    try:
        xor_value = int(left, 16) ^ int(right, 16)
    except ValueError:
        return None

    return xor_value.bit_count()


def is_matching_photo_hash(
    left_hash: Optional[str],
    right_hash: Optional[str],
    threshold: int = PHASH_DISTANCE_THRESHOLD,
) -> bool:
    distance = phash_distance(left_hash, right_hash)
    return distance is not None and distance <= threshold


def _fetch_all_profiles() -> list[dict[str, Any]]:
    response = get_supabase_client().table(TABLE_NAME).select("*").execute()
    return list(response.data or [])


def _fetch_photo_hash_candidates(photo_hash: Optional[str]) -> list[dict[str, Any]]:
    clean_hash = _clean_photo_hash(photo_hash)
    if not clean_hash:
        return []

    matches: list[dict[str, Any]] = []
    for profile in _fetch_all_profiles():
        profile_hash = _clean_photo_hash(profile.get("photo_hash"))
        if not profile_hash:
            continue
        distance = phash_distance(profile_hash, clean_hash)
        if distance is not None and distance <= PHASH_DISTANCE_THRESHOLD:
            matches.append(profile)

    return matches


def _merge_profiles(*profile_groups: list[dict[str, Any]]) -> list[dict[str, Any]]:
    merged: list[dict[str, Any]] = []
    seen_ids: set[Any] = set()

    for group in profile_groups:
        for profile in group:
            profile_id = profile.get("id")
            dedupe_key = profile_id if profile_id is not None else (
                profile.get("handle"),
                profile.get("phone"),
                profile.get("photo_hash"),
            )
            if dedupe_key in seen_ids:
                continue
            seen_ids.add(dedupe_key)
            merged.append(profile)

    return merged


def _query_profiles_eq(field: str, value: Optional[str]) -> list[dict[str, Any]]:
    if not value:
        return []
    response = get_supabase_client().table(TABLE_NAME).select("*").eq(field, value).execute()
    return list(response.data or [])


def _query_profiles_exact_triplet(
    *,
    handle: Optional[str],
    phone: Optional[str],
    photo_hash: Optional[str],
) -> list[dict[str, Any]]:
    clean_handle = _clean_handle(handle)
    clean_phone = _clean_phone(phone)
    clean_hash = _clean_photo_hash(photo_hash)

    if not all([clean_handle, clean_phone, clean_hash]):
        return []

    response = (
        get_supabase_client()
        .table(TABLE_NAME)
        .select("*")
        .eq("handle", clean_handle)
        .eq("phone", clean_phone)
        .eq("photo_hash", clean_hash)
        .execute()
    )
    return list(response.data or [])


def _query_profiles_ilike(pattern: str) -> list[dict[str, Any]]:
    if not pattern:
        return []
    response = get_supabase_client().table(TABLE_NAME).select("*").ilike("handle", pattern).execute()
    return list(response.data or [])


def _handle_search_patterns(handle: Optional[str]) -> list[str]:
    cleaned = _clean_handle(handle)
    normalized = normalize_handle(handle)
    if not cleaned and not normalized:
        return []

    patterns: list[str] = []
    seen: set[str] = set()

    def add_pattern(raw: Optional[str]) -> None:
        if not raw:
            return
        candidate = raw.lower()
        values = [candidate]
        if len(candidate) > 4:
            values.extend([candidate[:4], candidate[-4:]])
        for value in values:
            if len(value) < 3:
                continue
            pattern = f"%{value}%"
            if pattern not in seen:
                seen.add(pattern)
                patterns.append(pattern)

    add_pattern(cleaned)
    add_pattern(normalized)
    return patterns


def _fetch_candidate_profiles(
    *,
    handle: Optional[str],
    phone: Optional[str],
    photo_hash: Optional[str],
) -> list[dict[str, Any]]:
    direct_phone_matches = _query_profiles_eq("phone", phone)
    photo_hash_matches = _fetch_photo_hash_candidates(photo_hash)
    direct_handle_matches = _query_profiles_eq("handle", handle)
    handle_pattern_matches = [
        profile
        for pattern in _handle_search_patterns(handle)
        for profile in _query_profiles_ilike(pattern)
    ]

    candidates = _merge_profiles(
        direct_phone_matches,
        photo_hash_matches,
        direct_handle_matches,
        handle_pattern_matches,
    )

    if candidates:
        return candidates

    if handle and not (phone or photo_hash):
        return _fetch_all_profiles()

    return []


def _similarity_ratio(left: str, right: str) -> int:
    if _fuzz is not None:
        weighted_ratio = getattr(_fuzz, "WRatio", None)
        if callable(weighted_ratio):
            return int(weighted_ratio(left, right))
        return int(_fuzz.ratio(left, right))

    return int(SequenceMatcher(None, left, right).ratio() * 100)


def handle_similarity_score(left_handle: Optional[str], right_handle: Optional[str]) -> int:
    left_clean = _clean_handle(left_handle)
    right_clean = _clean_handle(right_handle)
    if not left_clean or not right_clean:
        return 0

    left_normalized = normalize_handle(left_clean) or left_clean.lower()
    right_normalized = normalize_handle(right_clean) or right_clean.lower()

    candidates = [
        _similarity_ratio(left_clean.lower(), right_clean.lower()),
        _similarity_ratio(left_normalized, right_normalized),
    ]
    return max(candidates)


def _candidate_score(
    profile: dict[str, Any],
    handle: Optional[str],
    phone: Optional[str],
    photo_hash: Optional[str],
) -> int:
    score = 0
    profile_handle = _clean_handle(profile.get("handle"))
    profile_phone = _clean_phone(profile.get("phone"))
    profile_hash = _clean_photo_hash(profile.get("photo_hash"))

    if handle and profile_handle:
        if profile_handle.lower() == handle.lower():
            score += 120
        else:
            similarity = handle_similarity_score(profile_handle, handle)
            if similarity >= HANDLE_FUZZY_MATCH_THRESHOLD:
                score += similarity

    if phone and profile_phone and profile_phone == phone:
        score += 140

    if photo_hash and profile_hash:
        distance = phash_distance(profile_hash, photo_hash)
        if distance == 0:
            score += 130
        elif distance is not None and distance <= PHASH_DISTANCE_THRESHOLD:
            score += 110 - distance

    return score


def find_matching_profile(
    *,
    handle: Optional[str] = None,
    phone: Optional[str] = None,
    photo_hash: Optional[str] = None,
) -> Optional[dict[str, Any]]:
    """
    2. Implement a function to query the database with exact and fuzzy matching for usernames
    4. Implement perceptual hash comparison function for profile photo matching
    """
    clean_handle = _clean_handle(handle)
    clean_phone = _clean_phone(phone)
    clean_hash = _clean_photo_hash(photo_hash)

    if not any([clean_handle, clean_phone, clean_hash]):
        return None

    best_match: Optional[dict[str, Any]] = None
    best_score = 0

    for profile in _fetch_candidate_profiles(
        handle=clean_handle,
        phone=clean_phone,
        photo_hash=clean_hash,
    ):
        score = _candidate_score(
            profile,
            handle=clean_handle,
            phone=clean_phone,
            photo_hash=clean_hash,
        )
        if score > best_score:
            best_match = profile
            best_score = score

    return best_match if best_score > 0 else None


def _build_profile_record(
    *,
    platform: str,
    handle: Optional[str],
    phone: Optional[str],
    photo_hash: Optional[str],
    flags: Optional[Iterable[str]],
    region: str,
) -> dict[str, Any]:
    today = date.today().isoformat()
    return {
        "platform": platform.strip(),
        "handle": _clean_handle(handle),
        "phone": _clean_phone(phone),
        "photo_hash": _clean_photo_hash(photo_hash),
        "report_count": 1,
        "first_reported": today,
        "last_reported": today,
        "common_flags": _dedupe_flags(flags),
        "region": region.strip(),
    }


def submit_scammer_report(
    *,
    platform: str,
    handle: Optional[str],
    phone: Optional[str] = None,
    photo_hash: Optional[str] = None,
    flags: Optional[Iterable[str]] = None,
    region: str,
) -> dict[str, Any]:
    """
    2. Implement a function to submit scammer reports (upsert by handle/phone/photo_hash)
    """
    if not platform or not platform.strip():
        raise ValueError("platform must not be empty")
    if not region or not region.strip():
        raise ValueError("region must not be empty")
    if not any([_clean_handle(handle), _clean_phone(phone), _clean_photo_hash(photo_hash)]):
        raise ValueError("At least one of handle, phone, or photo_hash is required")
    if not _dedupe_flags(flags):
        raise ValueError("flags must contain at least one non-empty value")

    client = get_supabase_client()
    match = find_matching_profile(handle=handle, phone=phone, photo_hash=photo_hash)

    if match is None:
        record = _build_profile_record(
            platform=platform,
            handle=handle,
            phone=phone,
            photo_hash=photo_hash,
            flags=flags,
            region=region,
        )
        response = client.table(TABLE_NAME).insert(record).execute()
        created = (response.data or [record])[0]
        report_count = int(created.get("report_count", 1))
        return {
            "success": True,
            "profile_status": status_from_report_count(report_count),
            "total_reports": report_count,
            "profile": created,
        }

    updated_flags = _dedupe_flags([*(match.get("common_flags") or []), *(flags or [])])
    updated_report_count = int(match.get("report_count") or 0) + 1
    update_payload = {
        "platform": platform.strip(),
        "handle": match.get("handle") or _clean_handle(handle),
        "phone": match.get("phone") or _clean_phone(phone),
        "photo_hash": match.get("photo_hash") or _clean_photo_hash(photo_hash),
        "report_count": updated_report_count,
        "last_reported": date.today().isoformat(),
        "common_flags": updated_flags,
        "region": match.get("region") or region.strip(),
    }
    response = (
        client.table(TABLE_NAME)
        .update(update_payload)
        .eq("id", match["id"])
        .execute()
    )
    updated = (response.data or [update_payload])[0]

    return {
        "success": True,
        "profile_status": status_from_report_count(updated_report_count),
        "total_reports": updated_report_count,
        "profile": updated,
    }


def check_profile(
    *,
    handle: Optional[str] = None,
    phone: Optional[str] = None,
    photo_hash: Optional[str] = None,
) -> dict[str, Any]:
    """
    2. Implement a function to query the database with exact and fuzzy matching for usernames
    4. Implement perceptual hash comparison function for profile photo matching
    """
    exact_triplet_matches = _query_profiles_exact_triplet(
        handle=handle,
        phone=phone,
        photo_hash=photo_hash,
    )

    if exact_triplet_matches:
        match = exact_triplet_matches[0]
    else:
        match = find_matching_profile(handle=handle, phone=phone, photo_hash=photo_hash)

    if match is None:
        return {
            "flagged": False,
            "status": None,
            "report_count": 0,
            "first_reported": None,
            "common_flags": [],
            "region": None,
            "matched_result": None,
        }

    report_count = int(match.get("report_count") or 0)
    return {
        "flagged": True,
        "status": status_from_report_count(report_count),
        "report_count": report_count,
        "first_reported": match.get("first_reported"),
        "common_flags": match.get("common_flags") or [],
        "region": match.get("region"),
        "matched_result": {
            "id": match.get("id"),
            "platform": match.get("platform"),
            "handle": match.get("handle"),
            "phone": match.get("phone"),
            "photo_hash": match.get("photo_hash"),
        },
    }
