"""LLM-based bio text parser — extracts identifiers and claims from social media bios."""

from __future__ import annotations

import os
from typing import List, Optional

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_openai import ChatOpenAI
from pydantic import BaseModel, Field


class ParsedBio(BaseModel):
    """Structured identifiers and claims extracted from a social media bio."""

    phone_numbers: List[str] = Field(
        default_factory=list,
        description="Phone numbers found in the bio, including country codes if present",
    )
    emails: List[str] = Field(
        default_factory=list,
        description="Email addresses found in the bio",
    )
    linked_handles: List[str] = Field(
        default_factory=list,
        description="Social media handles or usernames mentioned (e.g. @john_doe, t.me/john)",
    )
    location_claim: Optional[str] = Field(
        default=None,
        description="Claimed location or city/country (e.g. 'Singapore', 'London, UK')",
    )
    occupation_claim: Optional[str] = Field(
        default=None,
        description="Claimed job title or occupation (e.g. 'Cardiothoracic surgeon', 'Crypto investor')",
    )
    links: List[str] = Field(
        default_factory=list,
        description="URLs or links found in the bio",
    )


_SYSTEM_PROMPT = (
    "You are an OSINT analyst extracting contact identifiers and claims from social media bios. "
    "Your job is to identify phone numbers, email addresses, social handles, URLs, claimed locations, "
    "and claimed occupations/credentials from raw bio text. "
    "Be thorough — phone numbers may appear without spaces or with unusual formatting. "
    "Return empty lists/null if nothing is found for a field. "
    "Do not invent information that is not present in the bio."
)


def parse_bio(bio_text: str) -> dict:
    """
    Extract structured identifiers and claims from social media bio text.

    Uses LangChain structured output via OpenRouter. Returns a dict matching
    ParsedBio fields. Returns an empty ParsedBio dict on any failure.
    Never raises.
    """
    if not bio_text or not bio_text.strip():
        return ParsedBio().model_dump()

    try:
        llm = ChatOpenAI(
            base_url=os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1"),
            api_key=os.getenv("OPENROUTER_API_KEY", ""),
            model=os.getenv("OPENROUTER_CHAT_MODEL", "google/gemini-flash-1.5"),
            temperature=0,
            streaming=False,
        )
        chain = llm.with_structured_output(ParsedBio)
        result: ParsedBio = chain.invoke([
            SystemMessage(content=_SYSTEM_PROMPT),
            HumanMessage(content=f"Extract all identifiers and claims from this bio:\n\n{bio_text}"),
        ])
        return result.model_dump()
    except Exception:
        return ParsedBio().model_dump()
