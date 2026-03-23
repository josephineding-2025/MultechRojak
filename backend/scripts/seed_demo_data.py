"""Seed repeatable demo scammer profiles into Supabase."""

from __future__ import annotations

import sys
from datetime import date, timedelta
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parents[1]
ENV_PATH = BASE_DIR / ".env"
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

load_dotenv(dotenv_path=ENV_PATH)

from services.flagging import TABLE_NAME, get_supabase_client

DEMO_PROFILES = [
    {
        "platform": "Telegram",
        "handle": "@john_crypto88",
        "phone": "+60111111111",
        "photo_hash": "a1b2c3d4e5f60718",
        "report_count": 2,
        "days_ago": 18,
        "common_flags": ["money request", "fake investment"],
        "region": "MY",
    },
    {
        "platform": "Instagram",
        "handle": "@maya_travelsg",
        "phone": "+6588880001",
        "photo_hash": "0f0e0d0c0b0a0908",
        "report_count": 5,
        "days_ago": 31,
        "common_flags": ["identity inconsistency", "catfishing"],
        "region": "SG",
    },
    {
        "platform": "WhatsApp",
        "handle": "@captain.lee",
        "phone": "+639171234567",
        "photo_hash": "1122334455667788",
        "report_count": 11,
        "days_ago": 47,
        "common_flags": ["money request", "other"],
        "region": "PH",
    },
    {
        "platform": "X",
        "handle": "@rizalglobal_fx",
        "phone": "+6281234567890",
        "photo_hash": "89abcdef01234567",
        "report_count": 3,
        "days_ago": 12,
        "common_flags": ["fake investment", "identity inconsistency"],
        "region": "ID",
    },
]


def _upsert_profile(profile: dict) -> None:
    client = get_supabase_client()
    today = date.today()
    first_reported = (today - timedelta(days=profile["days_ago"])).isoformat()
    last_reported = today.isoformat()
    payload = {
        "platform": profile["platform"],
        "handle": profile["handle"],
        "phone": profile["phone"],
        "photo_hash": profile["photo_hash"],
        "report_count": profile["report_count"],
        "first_reported": first_reported,
        "last_reported": last_reported,
        "common_flags": profile["common_flags"],
        "region": profile["region"],
    }

    existing = (
        client.table(TABLE_NAME)
        .select("id")
        .eq("handle", profile["handle"])
        .limit(1)
        .execute()
    )
    rows = list(existing.data or [])
    if rows:
        (
            client.table(TABLE_NAME)
            .update(payload)
            .eq("id", rows[0]["id"])
            .execute()
        )
        print(f"updated {profile['handle']}")
        return

    client.table(TABLE_NAME).insert(payload).execute()
    print(f"inserted {profile['handle']}")


def main() -> None:
    print(f"Seeding demo profiles using {ENV_PATH}")
    for profile in DEMO_PROFILES:
        _upsert_profile(profile)
    print("Seed complete.")


if __name__ == "__main__":
    main()
