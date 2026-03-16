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
