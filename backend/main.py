import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from routers import chat, video, background_check, community

BASE_DIR = Path(__file__).resolve().parent
ENV_PATH = BASE_DIR / ".env"

load_dotenv(dotenv_path=ENV_PATH)

CORE_ENV_VARS = (
    "OPENROUTER_API_KEY",
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "SERPAPI_KEY",
    "NUMVERIFY_API_KEY",
)
OPTIONAL_ENV_VARS = (
    "OPENAI_API_KEY",
    "X_BEARER_TOKEN",
)
FEATURE_ENV_VARS = {
    "chat_analysis": ("OPENROUTER_API_KEY",),
    "video_frame_analysis": ("OPENROUTER_API_KEY",),
    "audio_analysis": ("OPENROUTER_API_KEY", "OPENAI_API_KEY"),
    "background_check": ("OPENROUTER_API_KEY", "SERPAPI_KEY", "NUMVERIFY_API_KEY"),
    "community": ("SUPABASE_URL", "SUPABASE_ANON_KEY"),
}

app = FastAPI(
    title="What is Fake Love — Backend",
    description="Romance scam detection API",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(chat.router)
app.include_router(video.router)
app.include_router(background_check.router)
app.include_router(community.router)


@app.get("/")
def root():
    return {"message": "Welcome to the What is Fake Love API. Go to /docs for documentation."}


def _env_status() -> dict:
    missing_core = [name for name in CORE_ENV_VARS if not os.getenv(name, "").strip()]
    missing_optional = [name for name in OPTIONAL_ENV_VARS if not os.getenv(name, "").strip()]
    capabilities = {
        name: all(os.getenv(var, "").strip() for var in env_vars)
        for name, env_vars in FEATURE_ENV_VARS.items()
    }

    return {
        "status": "ok",
        "version": "0.1.0",
        "readiness": "ready" if not missing_core else "config_needed",
        "missing_core_env": missing_core,
        "missing_optional_env": missing_optional,
        "capabilities": capabilities,
    }


@app.get("/health")
def health():
    return _env_status()
