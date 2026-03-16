"""
LLM Service — Owner: Member 2

This package contains the LangChain pipeline for:
  - Chat analysis (vision LLM via OpenRouter, batched frame processing)
  - Video frame analysis (vision LLM via OpenRouter, streaming alerts)
  - Audio transcription + LLM analysis (Whisper via direct OpenAI + OpenRouter for analysis)

## LLM Gateway: OpenRouter
All vision/chat LLM calls go through OpenRouter (https://openrouter.ai).
OpenRouter exposes an OpenAI-compatible API, so LangChain's ChatOpenAI works
with just a custom base_url:

    from langchain_openai import ChatOpenAI
    llm = ChatOpenAI(
        base_url="https://openrouter.ai/api/v1",
        api_key=os.environ["OPENROUTER_API_KEY"],
        model=os.environ["OPENROUTER_CHAT_MODEL"],   # e.g. "google/gemini-flash-1.5"
        streaming=True,   # enable for real-time video alerts
    )

## Real-time considerations
- For VIDEO monitoring: use streaming=True so alerts surface as soon as the
  model starts responding, rather than waiting for the full response.
- For CHAT analysis: streaming is optional — batch results are fine.
- Recommended low-latency models: google/gemini-flash-1.5, openai/gpt-4o-mini
  (set via OPENROUTER_CHAT_MODEL in .env)

## Audio transcription
Whisper is not available on OpenRouter. Keep direct OpenAI for transcription:
    openai.audio.transcriptions.create(model="whisper-1", ...)

Implementation steps:
  1. Initialize ChatOpenAI with OpenRouter base_url (see snippet above)
  2. Implement frame batching and deduplication for chat analysis
  3. Build the analysis chain with structured output (use .with_structured_output())
  4. For video: implement streaming response handler for real-time alerts
  5. Integrate into routers/chat.py and routers/video.py

See docs/SPEC.md Section 5 for the full LLM strategy and prompt design.
"""
