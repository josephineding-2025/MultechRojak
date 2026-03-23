# What is Fake Love Desktop App

Flutter desktop shell for the local romance-scam detection product.

## Run

```bash
flutter pub get
flutter run -d macos
```

The app expects the FastAPI backend to be running at `http://127.0.0.1:8000`.

## Current Features

- Chat monitor with silent screen capture and backend analysis
- Background check with live SSE progress updates
- Community lookup and gated reporting flow
- Video monitor shell and backend integration hooks

## Project Layout

- `lib/core/`: shared API, models, theme, and local state
- `lib/features/chat_monitor/`: capture + chat scan flow
- `lib/features/background_check/`: dossier + streaming OSINT flow
- `lib/features/community/`: community search and gated report submission
- `lib/features/video_monitor/`: video-call monitoring flow
