from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from routers import chat, video, background_check, community

BASE_DIR = Path(__file__).resolve().parent
ENV_PATH = BASE_DIR / ".env"

load_dotenv(dotenv_path=ENV_PATH)

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

@app.get("/health")
def health():
    return {"status": "ok", "version": "0.1.0"}
