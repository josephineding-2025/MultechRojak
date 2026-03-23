# What is Fake Love — Technical Specification

## 1. Project Overview

**What is Fake Love** is a desktop application that helps users in Southeast Asia detect romance scams in real time. It monitors on-screen chat conversations and video calls using AI, performs background checks on suspicious profiles, and connects to a community-sourced database of known scammers.

The app runs passively alongside any chat or video call platform — no integration required. It works by capturing the screen, analyzing content through vision-capable LLMs, and surfacing risk indicators to the user before serious harm occurs.

---

## 2. Target Users & Problem

### Target Users

- Young adults using dating apps or social platforms
- University students
- Migrant worker communities
- First-time internet users and elderly users
- Family members helping someone in a suspicious online relationship

### Problem

Romance scams in Southeast Asia are organized, scalable, and growing. Victims suffer financial loss, emotional trauma, identity theft, and in severe cases, exposure to cross-border exploitation networks. Most users realize they were targeted only after money has been sent or sensitive information shared.

There is currently no accessible, privacy-aware tool that helps users assess suspicious online relationships early — before damage occurs.

---

## 3. System Architecture

### Overview

The application uses a two-process architecture: a Flutter desktop frontend and a Python FastAPI backend. Both run locally on the user's machine and communicate over localhost HTTP.

```
┌──────────────────────────────────────────────┐
│              Flutter Desktop App              │
│  - Floating overlay UI                        │
│  - Screen capture (every 2fps)                │
│  - Frame deduplication                        │
│  - Risk report display                        │
│  - Community flag UI                          │
└────────────────────┬─────────────────────────┘
                     │ HTTP (localhost)
┌────────────────────▼─────────────────────────┐
│           Python FastAPI Backend              │
│  - Frame batching (LangChain)                 │
│  - Vision LLM analysis (GPT-4o / Gemini)      │
│  - Audio transcription (Whisper)              │
│  - Background check pipeline                  │
│  - Community DB interface (Supabase)          │
└──────────────────────────────────────────────┘
```

### Communication

All Flutter ↔ Python communication is over `localhost`. No data is routed through any intermediate server owned by this project.

---

## 4. Feature Specifications

### 4.1 Chat Monitor

**Purpose:** Analyze a scrolled chat conversation for romance scam patterns using a vision LLM.

**User flow:**

1. User opens the app — it appears as a small floating overlay panel pinned to the edge of the screen
2. User presses **"Scan Chat"**
3. App begins capturing screenshots at 2 frames per second silently in the background
4. User opens their chat app (WhatsApp, Telegram, dating app, or any platform) and scrolls through the conversation at a natural pace
5. User presses **"Analyze"** when done scrolling
6. Backend processes captured frames in batches and returns a structured risk report
7. Overlay expands to display the full report

**Overlay UI states:**

```
Idle        → [Scan Chat] button
Scanning    → ● Recording  |  [Analyze]
Analyzing   → Processing...
Report      → Risk score + red flags + actions
```

**Frame capture:**

- Capture rate: 2 frames per second
- Deduplication: each frame is compared to the previous; frames with no visible change are discarded
- Estimated frame reduction: 60–70% after deduplication
- Frames are held in memory only; not written to disk

**Analysis trigger:** Manual — user presses "Analyze" after scrolling. No continuous real-time feedback during scroll.

---

### 4.2 Video Call Monitor

**Purpose:** Detect suspicious patterns during a live video call through dual-channel monitoring — visual frames and live audio.

**User flow:**

1. User presses **"Monitor Video Call"**
2. App minimizes to system tray and enters passive monitoring mode
3. User starts their video call on any platform
4. App monitors in background:
   - Captures video frames periodically
   - Captures and transcribes system audio in real time
5. If a suspicious pattern is detected, a non-blocking sticky alert appears in the corner of the screen
6. After the call ends, user can view a full summary of all alerts triggered

**Visual monitoring:**

- Periodic frame capture (every 3–5 seconds)
- Checks for: face inconsistency across frames, video blur or loop artifacts, screen-sharing anomalies

**Audio monitoring:**

- System audio is captured and streamed to Whisper API for transcription
- Transcription is buffered in 20–30 second chunks and analyzed by LLM
- Detects: scripted speech patterns, money or transfer requests, urgency language, claimed location inconsistency

**Alert style:**

```
┌─────────────────────────────────┐
│  ⚠️  Red Flag Detected           │
│  "Urgent money transfer request" │
│  [Dismiss]      [See Details]    │
└─────────────────────────────────┘
```

- Always-on-top sticky window, positioned in corner
- Auto-dismisses after 10 seconds if ignored
- Does not cover or interrupt the video call

**Note on macOS audio capture:** Capturing system audio on macOS requires a virtual audio driver such as BlackHole. The app will prompt the user to install this on first launch if not already present.

---

### 4.3 Background Check

**Purpose:** Verify whether a claimed online identity is consistent with publicly available information.

**Inputs:**

- Profile picture (captured from screen)
- Username / handle
- Phone number (if shared in chat)
- Platform name

**Checks performed:**

| Check                    | Method                                         | Purpose                                                                       |
| ------------------------ | ---------------------------------------------- | ----------------------------------------------------------------------------- |
| Profile picture lookup   | Reverse image search (SerpAPI / Google Vision) | Detect if photo is scraped from the internet or used across multiple profiles |
| Profile picture hash     | Perceptual hash (pHash)                        | Match against community flagged photos                                        |
| Username cross-platform  | Sherlock (Python library)                      | Detect if username exists consistently or suspiciously across platforms       |
| Phone number validation  | NumVerify API                                  | Validate number, carrier, and country of origin                               |
| Social media consistency | Social Analyzer                                | Check if profile details are consistent across platforms                      |

**Output:**

```json
{
  "photo_found_online": true,
  "photo_sources": ["instagram.com/user123", "tinder_scraped_db"],
  "username_platforms": ["Telegram", "Instagram", "Reddit"],
  "phone_valid": true,
  "phone_country": "Nigeria",
  "phone_carrier": "MTN",
  "profile_consistency_score": 32,
  "background_summary": "Profile photo found on 2 unrelated accounts. Phone number registered in a different country than claimed."
}
```

**Future roadmap (not in MVP):**

- Investment advisor certificate verification (MAS Singapore, SEC)
- Professional license lookup by country
- Extended regulatory database checks

---

### 4.4 Community Flagging

**Purpose:** Allow users to report confirmed scammers and warn others who encounter the same profile.

**Data stored per scammer entry:**

```json
{
  "platform": "Telegram",
  "handle": "@john_crypto88",
  "phone": "+60123456789",
  "photo_hash": "a3f8bc92d1...",
  "report_count": 7,
  "first_reported": "2026-01-12",
  "last_reported": "2026-03-10",
  "common_flags": [
    "money request",
    "fake investment",
    "identity inconsistency"
  ],
  "region": "MY"
}
```

**Confidence tiers:**

| Report Count | Status    | Display                      |
| ------------ | --------- | ---------------------------- |
| 1–2          | Reported  | 🟡 Reported by users         |
| 3–9          | Flagged   | 🟠 Flagged by community      |
| 10+          | Confirmed | 🔴 Confirmed scammer profile |

**Submission rules:**

- Only users who completed a scan can submit a flag
- Minimum risk score of Medium required to unlock flagging
- Reporter identity is never stored — only the count increments

**Matching logic on profile check:**

- Username: exact match + fuzzy match (catches variations like `john88` vs `j0hn88`)
- Phone number: exact match
- Profile picture: perceptual hash comparison (catches cropped or filtered versions of the same photo)

**Display to user:**

```
⚠️  This profile has been flagged 7 times by other users.
    First reported: January 2026 | Region: Malaysia
    Common patterns: money request, fake investment
```

**Opt-out:** Users can disable community contribution in settings. Their scans remain local only.

---

## 5. LLM Strategy

### LLM Gateway: OpenRouter

All vision and chat LLM calls are routed through **OpenRouter** (`https://openrouter.ai/api/v1`), a unified API gateway that exposes an OpenAI-compatible interface across dozens of models. This lets us swap models via a single env var without changing code.

**Key advantages for this project:**

- Single API key for all models (GPT-4o, Gemini, Claude, etc.)
- OpenAI SDK / LangChain `ChatOpenAI` work out of the box with `base_url` override
- Per-request model selection — video alerts can use a faster model than full chat analysis
- Streaming supported — critical for real-time video alert latency

**Configured via `.env`:**

```
OPENROUTER_API_KEY=sk-or-...
OPENROUTER_CHAT_MODEL=google/gemini-flash-1.5   # swap to any vision model
```

**Recommended models:**

| Use case                       | Model                     | Reason                                     |
| ------------------------------ | ------------------------- | ------------------------------------------ |
| Chat analysis (batch)          | `openai/gpt-4o`           | Best quality for structured scam detection |
| Video frame alerts (real-time) | `google/gemini-flash-1.5` | Very low latency, strong vision            |
| Audio alert analysis           | `openai/gpt-4o-mini`      | Fast, cheap, text-only                     |
| Low-cost fallback              | `openai/gpt-4o-mini`      | 10× cheaper than gpt-4o                    |

**Audio transcription exception:** Whisper is not available on OpenRouter. The Whisper transcription step still calls the OpenAI API directly (`OPENAI_API_KEY`). Only the LLM analysis of the transcript goes through OpenRouter.

### Chat Analysis Pipeline

```
Screen frames
     ↓
Deduplication (skip visually similar frames)
     ↓
Batch frames (LangChain batch processing)
     ↓
OpenRouter → vision model (per-batch analysis)
     ↓
Aggregation chain — merge batch results
     ↓
Final risk report chain — structured JSON output
```

### Real-Time Video Analysis Pipeline

```
Video frame (every 3–5s)
     ↓
OpenRouter → vision model (streaming=True)
     ↓ (first token triggers alert — no wait for full response)
Sticky alert shown immediately
     ↓
Full response completes → alert details updated
```

### Prompt Design (Chat Analysis)

```
System:
You are a romance scam detection assistant. Analyze the provided chat
screenshots for patterns associated with romance scams. The conversation
may be in any language. Respond in English.

For each red flag detected, you MUST quote the specific message or
visual element that triggered it. Do not raise a flag without evidence.

Return a structured JSON response.

User:
[Batch of chat screenshot images]
```

### Structured Output Schema

```json
{
  "risk_level": "HIGH",
  "risk_score": 82,
  "red_flags": [
    {
      "pattern": "Urgent money request",
      "evidence": "Message: 'Please send $500 by tonight or I lose everything'",
      "severity": "critical"
    },
    {
      "pattern": "Avoided video verification",
      "evidence": "Three separate excuses given when video call was suggested",
      "severity": "high"
    }
  ],
  "summary": "This conversation shows multiple high-severity romance scam indicators including urgent financial requests and consistent avoidance of identity verification.",
  "recommended_actions": [
    "Do not send money or gift cards",
    "Request an in-person or verified video meeting",
    "Report to your local cybercrime authority"
  ]
}
```

### Confidence Score Formula

```
base_score          = LLM internal confidence (0–100)

weighted_flags      = (critical flags × 35)
                    + (high flags × 20)
                    + (medium flags × 10)
                    + (low flags × 5)

consistency_bonus   = (patterns appearing in 3+ frames) × 10

final_score         = min(100,
                      base_score × 0.4
                    + weighted_flags × 0.5
                    + consistency_bonus × 0.1)
```

**Risk thresholds:**

| Score  | Level    | Meaning          |
| ------ | -------- | ---------------- |
| 0–39   | Low      | Likely safe      |
| 40–64  | Medium   | Stay cautious    |
| 65–84  | High     | Probable scam    |
| 85–100 | Critical | Very likely scam |

### Multilingual Handling

All recommended OpenRouter models (GPT-4o, Gemini Flash, Claude) natively support Malay/Indonesian, Chinese, Thai, Vietnamese, Tagalog, and English. No additional translation layer is required. The prompt instructs the model to detect patterns regardless of language and respond in English.

### False Positive Prevention

- Every red flag must include a direct quote or visual evidence from the conversation
- A single urgent message does not trigger HIGH risk — weighted formula requires pattern accumulation
- Consistency bonus only applies when the same pattern appears across multiple frames

---

## 6. Privacy Model

### Principles

- Chat content is **never stored** on any server operated by this project
- Only the risk report (not the raw messages) is saved locally on the user's device
- Community flagging stores scammer identifiers only — no victim data
- Users can opt out of community contribution entirely

### Data Flow

| Data                   | Sent To                     | Retained By Us   |
| ---------------------- | --------------------------- | ---------------- |
| Chat frames (images)   | OpenRouter → vision model   | No               |
| Audio transcription    | OpenAI Whisper API (direct) | No               |
| Profile picture        | SerpAPI / Google Vision     | No               |
| Scammer handle / phone | Supabase community DB       | Yes (anonymized) |
| Risk report            | Local device only           | Local only       |
| Reporter identity      | Not collected               | Never            |

### Third-Party API Compliance

- All API calls use HTTPS
- Frames are not logged or stored by this project after API response
- Users are informed of third-party data processing during onboarding

---

## 7. Tech Stack

### Frontend

| Component             | Technology                        |
| --------------------- | --------------------------------- |
| Desktop app framework | Flutter (Windows / macOS)         |
| Screen capture        | `screen_capturer` Flutter package |
| HTTP client           | `dio`                             |
| Local storage         | `shared_preferences` / SQLite     |
| Overlay window        | `window_manager` Flutter package  |

### Backend

| Component                | Technology                                                       |
| ------------------------ | ---------------------------------------------------------------- |
| API framework            | Python FastAPI                                                   |
| LLM orchestration        | LangChain                                                        |
| LLM gateway              | OpenRouter (OpenAI-compatible, model-agnostic)                   |
| Vision LLM               | Any OpenRouter vision model (default: `google/gemini-flash-1.5`) |
| Audio transcription      | OpenAI Whisper API (direct — not via OpenRouter)                 |
| Screen capture (backend) | `mss` (Python)                                                   |
| Face / frame analysis    | OpenCV                                                           |
| Username OSINT           | Sherlock (Python)                                                |
| Social profile analysis  | Social Analyzer                                                  |
| Reverse image search     | SerpAPI                                                          |
| Phone validation         | NumVerify API                                                    |
| Perceptual hashing       | `imagehash` (Python)                                             |
| Community database       | Supabase (PostgreSQL + REST API)                                 |

---

## 8. API Contract (Flutter ↔ Python)

### `POST /analyze-chat`

Analyze a batch of chat screenshot frames.

**Request:**

```json
{
  "frames": ["base64_image_1", "base64_image_2", "..."],
  "platform": "WhatsApp",
  "session_id": "uuid"
}
```

**Response:**

```json
{
  "risk_level": "HIGH",
  "risk_score": 82,
  "red_flags": [...],
  "summary": "...",
  "recommended_actions": [...]
}
```

---

### `POST /analyze-video-frame`

Analyze a single video call frame.

**Request:**

```json
{
  "frame": "base64_image",
  "session_id": "uuid"
}
```

**Response:**

```json
{
  "alert": true,
  "reason": "Face inconsistency detected across frames",
  "severity": "high"
}
```

---

### `POST /analyze-audio-chunk`

Analyze a transcribed audio chunk from a live call.

**Request:**

```json
{
  "audio_b64": "base64_audio",
  "session_id": "uuid"
}
```

**Response:**

```json
{
  "transcription": "Can you please send me $500 tonight...",
  "alert": true,
  "reason": "Urgent money request detected in speech",
  "severity": "critical"
}
```

---

### `POST /background-check`

Run a background check on a profile.

**Request:**

```json
{
  "username": "john_crypto88",
  "platform": "Telegram",
  "phone": "+60123456789",
  "photo_b64": "base64_image"
}
```

**Response:**

```json
{
  "photo_found_online": true,
  "photo_sources": ["instagram.com/user123"],
  "username_platforms": ["Telegram", "Reddit"],
  "phone_valid": true,
  "phone_country": "Nigeria",
  "profile_consistency_score": 32,
  "background_summary": "..."
}
```

---

### `POST /flag-scammer`

Submit a community flag for a scammer profile.

**Request:**

```json
{
  "platform": "Telegram",
  "handle": "@john_crypto88",
  "phone": "+60123456789",
  "photo_hash": "a3f8bc92d1...",
  "flags": ["money request", "fake investment"],
  "region": "MY"
}
```

**Response:**

```json
{
  "success": true,
  "profile_status": "flagged",
  "total_reports": 8
}
```

---

### `GET /check-profile`

Check if a profile matches any community-flagged entries.

**Request params:** `?handle=john_crypto88&phone=+60123456789&photo_hash=a3f8bc92d1`

**Response:**

```json
{
  "flagged": true,
  "status": "flagged",
  "report_count": 7,
  "first_reported": "2026-01-12",
  "common_flags": ["money request", "fake investment"],
  "region": "MY"
}
```

---

## 9. MVP Scope (Hackathon Build)

The hackathon MVP demonstrates the full concept with one working end-to-end flow.

### In scope

- [ ] Flutter desktop app with floating overlay UI
- [ ] Screen capture and frame deduplication
- [ ] Chat analysis via OpenRouter vision model (batched, LangChain)
- [ ] Risk report display (score, red flags, recommendations)
- [ ] Basic background check (reverse image search + username check)
- [ ] Community flagging (submit + check against Supabase DB)
- [ ] Video call frame monitoring + sticky alert popup
- [ ] Audio capture + Whisper transcription + LLM alert

### Out of scope (future roadmap)

- Investment advisor / professional license verification
- Extended regulatory database checks (MAS, SEC)
- Mobile version
- Complex ML-based deepfake detection
- Advanced face consistency analysis
- Multi-user dashboard / admin panel

---

## 10. Future Roadmap

| Feature                      | Description                                                       |
| ---------------------------- | ----------------------------------------------------------------- |
| Investment cert verification | Check MAS Singapore, SEC, and other national regulatory databases |
| Professional license lookup  | Verify claimed credentials against country-specific registries    |
| Deepfake detection           | Frame-level deepfake classification using dedicated ML model      |
| Mobile app                   | iOS / Android companion app                                       |
| Browser extension            | In-browser overlay for web-based chat platforms                   |
| ASEAN language packs         | Optimized prompts and scam pattern libraries per language/country |
| NGO / platform API           | Allow dating apps and NGOs to integrate checks via API            |
| Advanced scam pattern DB     | Curated, versioned database of known scam scripts per region      |

## 11. Team Ownership

| Member       | Feature                      | Files                                                                                                                                               |
| ------------ | ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| You (choijs) | Background Check             | `backend/routers/background_check.py`, `backend/services/osint/`, `app/lib/features/background_check/`                                              |
| Josephine    | Chat Monitor + Video Monitor | `backend/routers/chat.py`, `backend/routers/video.py`, `backend/services/llm/`, `app/lib/features/chat_monitor/`, `app/lib/features/video_monitor/` |
| Chris        | Community Scammer List       | `backend/routers/community.py`, `backend/services/flagging/`, `app/lib/features/community/`                                                         |

---

## 12. Implementation Roadmap

Phases run roughly sequentially. Within each phase, all three members work in parallel on their own vertical slice. Check off items as they are completed.

**Status legend:** `[ ]` not started · `[~]` in progress · `[x]` done

---

### Phase 0 — Scaffold ✅

> Prerequisite: everyone can clone and run the app before writing a single line of real logic.

- [x] Repo foundation (`.gitignore`, `.env.example`, `README.md`)
- [x] Python backend: FastAPI + CORS + `/health` + 4 mock routers
- [x] Flutter app: window setup, 4-tab shell, backend health banner
- [x] All 4 features: placeholder screens + `FutureProvider` stubs + service stubs
- [x] `docs/SPEC.md` finalised — API contracts locked

---

### Phase 1 — Backend Real Implementation

> Goal: every endpoint returns real data. Flutter stays on mocks during this phase — no Flutter work required.

#### Shared (All Members)
- [x] Copy `.env.example` → `.env`, fill in own API keys
- [x] Run `pip install -r requirements.txt` and confirm `uvicorn main:app --reload` starts clean
- [x] Verify `/docs` shows all 6 endpoints and each returns mock JSON

#### You — Background Check Backend
- [x] `services/osint/`: reverse image search via SerpAPI — return list of matching URLs
- [x] `services/osint/`: pHash computation for uploaded photo (`imagehash` library)
- [x] `services/osint/`: username cross-platform lookup via Sherlock — return list of found platforms
- [x] `services/osint/`: phone validation via NumVerify API — return country + carrier + validity
- [x] `services/osint/`: aggregate all results into `BackgroundCheckResult`, compute `profile_consistency_score`
- [x] `routers/background_check.py`: replace mock return with real `services/osint/` call
- [x] Manual test: POST `/background-check` with a real username/phone → non-mock response
- [x] **BONUS:** Proportional scoring (Username=40/Phone=30/Photo=30 weights, only counts checks that ran)
- [x] **BONUS:** `check_platform_authenticity()` — X API + GitHub API deep account verification (verified, followers, account age, human-readable note); `platform_verified`, `platform_followers`, `platform_account_age_days`, `authenticity_note` added to response

#### Josephine — Chat + LLM Backend
- [x] `services/llm/`: initialise `ChatOpenAI` with OpenRouter `base_url`, `OPENROUTER_API_KEY`, `OPENROUTER_CHAT_MODEL`
- [x] `services/llm/`: build chat analysis chain — prompt + structured output (`.with_structured_output()`) → `RiskReport`
- [x] `services/llm/`: implement frame batching (group frames into batches of ≤10, send each batch separately, aggregate)
- [x] `services/llm/`: build video frame analysis function (single frame → `VideoAlert`)
- [x] `routers/chat.py`: replace mock return with real LangChain chain call
- [x] `routers/video.py` (`/analyze-video-frame`): replace mock with real vision LLM call
- [~] Manual test: POST `/analyze-chat` with 2–3 real base64 screenshots → structured risk report

#### Chris — Community Flagging Backend
- [ ] Create Supabase project; add `SUPABASE_URL` + `SUPABASE_ANON_KEY` to `.env`
- [ ] Create `scammer_profiles` table in Supabase (columns: `platform`, `handle`, `phone`, `photo_hash`, `report_count`, `first_reported`, `last_reported`, `common_flags`, `region`)
- [ ] `services/flagging/`: implement upsert — if handle/phone/hash exists increment `report_count`, else insert new row
- [ ] `services/flagging/`: implement exact-match profile check — query by handle + phone + photo_hash
- [ ] `services/flagging/`: map `report_count` → `profile_status` (1–2: `reported`, 3–9: `flagged`, 10+: `confirmed`)
- [ ] `routers/community.py`: replace both mock returns with real Supabase calls
- [ ] Manual test: POST `/flag-scammer` → row appears in Supabase dashboard; GET `/check-profile` → returns that row

---

### Phase 2 — Flutter Feature Screens

> Goal: each member's Flutter screen makes real API calls and displays real results. Backend from Phase 1 must be running.

#### Shared (All Members)
- [ ] Confirm `flutter pub get` succeeds and app launches on macOS/Windows
- [ ] Verify backend health banner appears when `uvicorn` is not running

#### You — UI Redesign (do before teammates build their screens)
- [~] Replace current UI with new design — implement new design system / shell before Josephine and Chris start Phase 2 Flutter work
- [~] Ensure new design patterns are communicated to teammates so they build consistently

#### You — Background Check Screen
- [x] `background_check_screen.dart`: form with fields — username, platform (dropdown), phone (optional), photo capture button (optional, use `screen_capturer` to crop region)
- [x] Wire "Run Check" button to `backgroundCheckProvider` — show loading spinner
- [x] Results card: display `profile_consistency_score` as a coloured progress bar (green ≥70, orange 40–69, red <40)
- [x] Results card: list `photo_sources` if `photo_found_online` is true
- [x] Results card: show `phone_country` + `phone_carrier` + validity indicator
- [x] Results card: display `username_platforms` as chip list
- [x] Results card: show `background_summary` text
- [x] Error state: display message if API call fails
- [x] **BONUS:** Account Authenticity section — verified chip, followers chip (formatted), account age chip (red if <90 days), color-coded note banner

#### Josephine — Chat Monitor Screen
- [ ] `chat_monitor_screen.dart`: implement the 4 UI states (Idle → Scanning → Analyzing → Report)
- [ ] "Scan Chat" button: start `screen_capturer` timer at 2 fps, store frames in memory as base64 list
- [ ] Frame deduplication: before appending, compare last frame hash to current — skip if identical
- [ ] "Analyze" button: stop capture, call `chatAnalysisProvider` with collected frames, show spinner
- [ ] Risk report card: coloured risk level badge (green/orange/red/dark-red), large score number
- [ ] Risk report card: expandable list of `red_flags` — each shows pattern + evidence + severity icon
- [ ] Risk report card: `recommended_actions` as bullet list
- [ ] Risk report card: "Flag This Profile" button → navigates to Community tab (pre-fills handle if known)

#### Josephine — Video Monitor Screen
- [ ] `video_monitor_screen.dart`: "Monitor Video Call" button → enter monitoring mode
- [ ] Monitoring mode: start frame capture every 4 seconds, call `/analyze-video-frame` per frame
- [ ] Sticky alert overlay: when `alert=true`, show floating alert widget (always-on-top, auto-dismiss after 10s)
- [ ] "Stop Monitoring" button: stop capture, show session summary of all triggered alerts
- [ ] Session summary: list of all alerts with timestamp + reason + severity

#### Chris — Community Screen
- [ ] `community_screen.dart`: two tabs — "Check Profile" and "Flag Scammer"
- [ ] Check Profile tab: inputs for handle + phone + photo hash (optional); "Check" button → calls `profileCheckProvider`
- [ ] Check result: show confidence tier badge (🟡 Reported / 🟠 Flagged / 🔴 Confirmed) based on `status`
- [ ] Check result: display `report_count`, `first_reported`, `region`, `common_flags`
- [ ] Flag Scammer tab: form — platform, handle, phone, flags (multi-select checklist), region
- [ ] Flag form: "Submit" button → calls `flagScammerProvider` → show success message with new `total_reports`
- [ ] Guard: disable Flag tab if no completed scan with risk score ≥ Medium in session (show "Complete a scan first")

---

### Phase 3 — Real-Time Audio + Advanced Matching

> Goal: live video call monitoring works end-to-end; background check and community matching are more robust.

#### Josephine — Audio Pipeline
- [ ] macOS: detect BlackHole installation on app launch; if missing, show install prompt with download link
- [x] `services/llm/`: Whisper transcription — accept raw audio bytes, call `openai.audio.transcriptions.create(model="whisper-1")`
- [x] `services/llm/`: audio analysis chain — feed transcript to OpenRouter LLM, return `AudioAlert`
- [x] `routers/video.py` (`/analyze-audio-chunk`): replace mock with Whisper + LLM pipeline
- [ ] Flutter: system audio capture in `video_monitor_service.dart` (buffer 20s chunks, send to `/analyze-audio-chunk`)
- [ ] Flutter: audio alerts surface in the same sticky overlay as video frame alerts

#### Josephine — Streaming Video Alerts
- [ ] Switch `/analyze-video-frame` to streaming mode (`streaming=True` on LangChain model)
- [ ] Flutter: handle streaming response — show alert immediately on first token, update detail text as stream completes

#### You — pHash Community Integration
- [x] `services/osint/`: when photo is provided, compute pHash and pass to `/check-profile` call (cross-check against community DB)
- [x] `background_check_screen.dart`: if community DB returns a match on photo hash, surface it prominently in results

#### Chris — Advanced Matching
- [ ] `services/flagging/`: fuzzy username matching — normalise handle (lowercase, strip @, replace 0→o, 1→l) before query
- [ ] `services/flagging/`: pHash photo comparison — on `/check-profile`, fetch all stored `photo_hash` values and compute hamming distance (threshold ≤10)
- [ ] Supabase: add index on `handle` and `phone` columns for query performance

---

### Phase 4 — Integration, Polish & Demo

> Goal: the demo flow works flawlessly end-to-end. One rehearsed scenario per feature.

#### Integration
- [ ] End-to-end flow: chat scan → risk report → click "Flag This Profile" → community flag submitted → check-profile returns flag
- [ ] Supabase: seed demo data — 3–5 fake scammer profiles with varying report counts to demonstrate all confidence tiers
- [ ] Confirm app runs on both macOS and Windows (run `flutter run -d windows` on Windows machine)

#### Error Handling & Edge Cases
- [ ] Backend down: Flutter shows "Start the backend first" banner (already in shell) — verify it clears when backend comes back
- [ ] API key missing: backend returns `500` with clear message; Flutter shows error state (not crash)
- [ ] Empty frames: chat analysis with 0 frames returns graceful error, not 500
- [ ] No community match: `/check-profile` with unknown handle returns `{ "flagged": false }` — Flutter shows "No reports found" state

#### Demo Polish
- [ ] Window size and always-on-top work correctly alongside a full-screen chat app
- [ ] All 4 tab screens have no placeholder "TODO" text visible in demo scenario
- [ ] Risk score colour coding is consistent across chat results and video alerts
- [ ] App icon set for macOS and Windows builds

#### Final Checklist Before Demo
- [ ] `.env` filled in on demo machine with all real API keys
- [ ] Supabase project accessible (not paused due to inactivity)
- [ ] Backend starts in under 5 seconds on demo machine
- [ ] Flutter app launches and all 4 tabs load without errors
- [ ] One complete demo run rehearsed: open chat app → scan → analyze → see HIGH risk → flag profile → check profile → see 🟠 Flagged
