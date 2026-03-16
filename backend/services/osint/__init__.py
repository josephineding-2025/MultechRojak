"""
OSINT Service — Owner: Member 1

This package contains the background check pipeline:
  - Reverse image search via SerpAPI
  - Perceptual image hashing (pHash) for community photo matching
  - Username cross-platform check via Sherlock
  - Phone number validation via NumVerify API
  - Social media consistency via Social Analyzer

Implementation steps:
  1. Implement reverse image search with SerpAPI
  2. Add pHash computation using imagehash library
  3. Integrate Sherlock for username lookup
  4. Call NumVerify for phone validation
  5. Aggregate results into BackgroundCheckResult

See docs/SPEC.md Section 4.3 for the full background check spec.
"""
