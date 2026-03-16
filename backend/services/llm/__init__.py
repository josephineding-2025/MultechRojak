"""
LLM Service — Owner: Member 2

This package contains the LangChain pipeline for:
  - Chat analysis (GPT-4o Vision, batched frame processing)
  - Video frame analysis (vision LLM)
  - Audio transcription + LLM analysis (Whisper + GPT-4o)

Implementation steps:
  1. Set up LangChain chat model with GPT-4o or Gemini
  2. Implement frame batching and deduplication
  3. Build the analysis chain with structured output
  4. Integrate into routers/chat.py and routers/video.py

See docs/SPEC.md Section 5 for the full LLM strategy and prompt design.
"""
