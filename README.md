# What is Fake Love

A desktop app that helps users in Southeast Asia detect romance scams in real time.

## Team Ownership

| Member | Feature | Files |
|--------|---------|-------|
| Member 1 | Background Check | `backend/routers/background_check.py`, `backend/services/osint/`, `app/lib/features/background_check/` |
| Member 2 | Chat Monitor + Video Monitor | `backend/routers/chat.py`, `backend/routers/video.py`, `backend/services/llm/`, `app/lib/features/chat_monitor/`, `app/lib/features/video_monitor/` |
| Member 3 | Community Flagging | `backend/routers/community.py`, `backend/services/flagging/`, `app/lib/features/community/` |

## Setup

### 1. Clone and set up environment

```bash
git clone <repo>
cd aiReadyAsean
cp .env.example .env
# Fill in your API keys in .env
```

### 2. Start the backend

```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```

Visit `http://127.0.0.1:8000/docs` to see all endpoints.

### 3. Start the Flutter app

```bash
cd app
flutter pub get
flutter run -d macos   # or -d windows
```

The app launches as a small always-on-top overlay window with 4 tabs.

### 4. First-time Flutter setup (macOS/Windows platforms)

If `app/macos/` or `app/windows/` don't exist yet:

```bash
cd app
flutter create . --platforms=macos,windows
flutter pub get
```

## Architecture

- **Flutter desktop app**: floating overlay, screen capture, UI
- **Python FastAPI backend**: LLM analysis, OSINT, community DB
- Both run locally on the user's machine over `localhost:8000`

See `docs/SPEC.md` for the full technical specification.
