"""Playwright-based headless scraper for public social media profiles."""

from __future__ import annotations

import base64
import os
from urllib.parse import urlparse

# playwright is imported lazily inside scrape_profile to avoid import errors
# if playwright is not yet installed.


def _detect_platform(url: str) -> str:
    """Return canonical platform name from a profile URL."""
    try:
        netloc = urlparse(url).netloc.lower().lstrip("www.")
        if "instagram.com" in netloc:
            return "instagram"
        if "twitter.com" in netloc or "x.com" in netloc:
            return "twitter"
        if "github.com" in netloc:
            return "github"
        if "tiktok.com" in netloc:
            return "tiktok"
        if "linkedin.com" in netloc:
            return "linkedin"
    except Exception:
        pass
    return "unknown"


def _username_from_url(url: str) -> str:
    """Extract the first non-empty path segment as the username."""
    try:
        path = urlparse(url).path.strip("/")
        segment = path.split("/")[0]
        return segment.lstrip("@") if segment else ""
    except Exception:
        return ""


async def _scrape_instagram(page, username: str) -> dict:
    """Scrape a public Instagram profile page."""
    result: dict = {}
    try:
        await page.goto(
            f"https://www.instagram.com/{username}/",
            wait_until="domcontentloaded",
            timeout=30000,
        )
        # Wait for meta description (contains follower info on public pages)
        await page.wait_for_selector("meta[name='description']", timeout=8000)

        # Bio from og:description meta tag
        bio_text = await page.evaluate(
            "() => document.querySelector('meta[name=\"description\"]')?.content || ''"
        )
        result["bio_text"] = bio_text

        # Follower count — parse from description text if present
        # Instagram meta description format: "N Followers, N Following, N Posts"
        import re
        follower_match = re.search(r"([\d,]+)\s+Followers", bio_text or "")
        if follower_match:
            result["follower_count"] = int(follower_match.group(1).replace(",", ""))

        # Profile photo — og:image
        photo_url = await page.evaluate(
            "() => document.querySelector('meta[property=\"og:image\"]')?.content || ''"
        )
        if photo_url:
            photo_b64 = await _fetch_image_as_b64(page, photo_url)
            if photo_b64:
                result["photo_b64"] = photo_b64

    except Exception as exc:
        result["scrape_error"] = str(exc)

    return result


async def _scrape_twitter(page, username: str) -> dict:
    """Scrape a public X/Twitter profile page."""
    result: dict = {}
    try:
        await page.goto(
            f"https://x.com/{username}",
            wait_until="domcontentloaded",
            timeout=30000,
        )
        # Wait for profile to hydrate
        await page.wait_for_selector(
            "[data-testid='UserName'], [data-testid='UserDescription']",
            timeout=12000,
        )

        # Bio text
        try:
            bio_text = await page.locator("[data-testid='UserDescription']").inner_text(timeout=5000)
            result["bio_text"] = bio_text
        except Exception:
            result["bio_text"] = ""

        # Follower count
        try:
            followers_text = await page.locator(
                "a[href$='/followers'] span"
            ).first.inner_text(timeout=5000)
            result["follower_count"] = _parse_follower_count(followers_text)
        except Exception:
            pass

        # Following count
        try:
            following_text = await page.locator(
                "a[href$='/following'] span"
            ).first.inner_text(timeout=5000)
            result["following_count"] = _parse_follower_count(following_text)
        except Exception:
            pass

        # Profile photo
        try:
            photo_url = await page.locator(
                "img[src*='profile_images']"
            ).first.get_attribute("src", timeout=5000)
            if photo_url:
                # Get higher-res version
                photo_url = photo_url.replace("_normal", "_400x400")
                photo_b64 = await _fetch_image_as_b64(page, photo_url)
                if photo_b64:
                    result["photo_b64"] = photo_b64
        except Exception:
            pass

    except Exception as exc:
        result["scrape_error"] = str(exc)

    return result


def _parse_follower_count(text: str) -> int | None:
    """Parse '12.5K', '1.2M', '850' style follower counts."""
    try:
        text = text.strip().replace(",", "")
        if text.endswith("K"):
            return int(float(text[:-1]) * 1_000)
        if text.endswith("M"):
            return int(float(text[:-1]) * 1_000_000)
        return int(text)
    except Exception:
        return None


async def _fetch_image_as_b64(page, url: str) -> str | None:
    """Fetch an image URL via browser context and return as base64."""
    try:
        image_bytes = await page.evaluate(
            """async (url) => {
                const resp = await fetch(url);
                const buf = await resp.arrayBuffer();
                const bytes = new Uint8Array(buf);
                let binary = '';
                for (let i = 0; i < bytes.byteLength; i++) {
                    binary += String.fromCharCode(bytes[i]);
                }
                return btoa(binary);
            }""",
            url,
        )
        return image_bytes if image_bytes else None
    except Exception:
        return None


async def scrape_profile(profile_url: str) -> dict:
    """
    Headless-scrape a public social media profile URL.

    Returns a dict with keys (all Optional, default None/empty):
      platform        str   — detected platform name
      username        str   — handle extracted from URL
      bio_text        str   — raw bio / description text
      photo_b64       str   — base64-encoded profile photo
      follower_count  int   — follower count if visible
      following_count int   — following count if visible
      account_age_days int  — days since account creation (if visible)
      post_count      int   — post count if visible
      raw_url         str   — original input URL

    Sets 'scrape_error' (str) if something went wrong.
    Never raises — always returns a partial dict.
    """
    result: dict = {
        "raw_url": profile_url,
        "platform": _detect_platform(profile_url),
        "username": _username_from_url(profile_url),
        "bio_text": "",
        "photo_b64": None,
        "follower_count": None,
        "following_count": None,
        "account_age_days": None,
        "post_count": None,
    }

    try:
        from playwright.async_api import async_playwright  # lazy import

        platform = result["platform"]
        username = result["username"]

        if not username:
            result["scrape_error"] = "Could not extract username from URL"
            return result

        async with async_playwright() as pw:
            browser = await pw.chromium.launch(headless=True)
            context = await browser.new_context(
                user_agent=(
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/124.0.0.0 Safari/537.36"
                ),
                viewport={"width": 1280, "height": 800},
            )
            page = await context.new_page()

            platform_data: dict = {}
            if platform == "instagram":
                platform_data = await _scrape_instagram(page, username)
            elif platform in ("twitter", "x"):
                platform_data = await _scrape_twitter(page, username)
            else:
                result["scrape_error"] = f"Unsupported platform: {platform}"

            await browser.close()

        result.update(platform_data)

    except ImportError:
        result["scrape_error"] = (
            "playwright not installed — run: pip install playwright && playwright install chromium"
        )
    except Exception as exc:
        result["scrape_error"] = str(exc)

    return result
