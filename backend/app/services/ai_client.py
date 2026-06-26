"""
Thin client that calls the separate `ai_service` (the ML models).
Keeping ML in its own service means the core backend stays light and the
heavy TensorFlow/Transformers deps live only in ai_service.

If the AI service is down, we degrade gracefully with a clear message instead
of crashing the whole request.
"""
import re

import httpx

from app.config import settings
from app.services import dataset_kb, farm_kb

# Generous: the AI service loads each model lazily on its first request, and a
# cold CNN / FLAN-T5 load + inference on CPU can take a while.
TIMEOUT = 120.0


def _is_low_quality(answer: str | None) -> bool:
    """True if a model answer is empty or degenerate (looping/repetitive).

    The tiny FLAN-T5 model frequently gets stuck repeating a phrase, e.g.
    "a plant with a plant with a plant…". We catch that here so we can fall
    back to the curated knowledge base instead of showing the user garbage.
    """
    if not answer:
        return True
    text = answer.strip()
    if len(text) < 8:
        return True
    words = re.findall(r"[a-zA-Z]+", text.lower())
    if len(words) >= 6:
        # Heavy looping shows up as a very low unique-word ratio, or one short
        # phrase (bigram) repeated many times.
        unique_ratio = len(set(words)) / len(words)
        if unique_ratio < 0.45:
            return True
        bigrams = list(zip(words, words[1:]))
        if bigrams:
            top = max(set(bigrams), key=bigrams.count)
            if bigrams.count(top) >= 4:
                return True
        # Sentence-level looping: the small model often restates the same clause,
        # e.g. "X is a fungus in the family Y. It is a fungus in the family Y."
        # That repeats a long n-gram. Any 4-word sequence occurring 2+ times is a
        # strong signal of this degenerate echo (rare in genuine answers).
        fourgrams = list(zip(words, words[1:], words[2:], words[3:]))
        if fourgrams:
            top4 = max(set(fourgrams), key=fourgrams.count)
            if fourgrams.count(top4) >= 2:
                return True
    return False


def _echoes_question(answer: str | None, question: str) -> bool:
    """True if the model just parroted the question back instead of answering.

    The small model frequently echoes terse inputs (e.g. answering
    "rice, sandy soil" with "Rice, sandy soil") — useless, so we reject it and
    fall back to a real retrieved answer.
    """
    if not answer:
        return True
    a = set(re.findall(r"[a-z]+", answer.lower()))
    q = set(re.findall(r"[a-z]+", dataset_kb.unframe(question).lower()))
    if not a or not q:
        return False
    # Almost all of the answer's words came straight from the question, and it
    # adds little of its own.
    overlap = len(a & q) / len(a)
    return overlap >= 0.8 and len(a - q) <= 2


async def predict_disease(image_bytes: bytes, filename: str) -> dict:
    """POST the crop image to ai_service /predict/crop."""
    url = f"{settings.AI_SERVICE_URL}/predict/crop"
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            files = {"image": (filename, image_bytes, "application/octet-stream")}
            r = await client.post(url, files=files)
            r.raise_for_status()
            return r.json()
    except httpx.HTTPError as e:
        return {"disease": None, "confidence": 0.0,
                "recommendation": f"AI service unavailable: {e}"}


async def predict_fertilizer(features: dict) -> dict:
    """POST soil/crop features to ai_service /predict/fertilizer."""
    url = f"{settings.AI_SERVICE_URL}/predict/fertilizer"
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            r = await client.post(url, json=features)
            r.raise_for_status()
            return r.json()
    except httpx.HTTPError as e:
        return {"predicted_fertilizer": None, "confidence": 0.0,
                "detail": f"AI service unavailable: {e}"}


# System prompt that keeps GPT focused and useful for farmers.
_FARM_SYSTEM_PROMPT = (
    "You are AgriPulse, an expert agricultural assistant for farmers. "
    "Answer questions about crops, soil, fertilizers, pests, diseases, weather "
    "and farming practices with clear, practical, accurate advice. Keep answers "
    "concise and easy to act on. If a question is outside farming, gently say so."
)


def _build_prompt(question: str, context: str | None) -> str:
    """Fold the retrieved DB context (if any) into the prompt the model sees.

    With context this becomes the classic RAG shape:

        Context:
        <facts from the database>

        Question:
        <user question>

        Answer:
    """
    if not context:
        return question
    return (
        "Context:\n"
        f"{context}\n\n"
        "Question:\n"
        f"{question}\n\n"
        "Answer:"
    )


async def _chat_gpt(question: str, context: str | None = None) -> dict:
    """Ask OpenAI's GPT directly (used when OPENAI_API_KEY is configured)."""
    url = f"{settings.OPENAI_BASE_URL}/chat/completions"
    headers = {"Authorization": f"Bearer {settings.OPENAI_API_KEY}"}
    payload = {
        "model": settings.OPENAI_MODEL,
        "messages": [
            {"role": "system", "content": _FARM_SYSTEM_PROMPT},
            {"role": "user", "content": _build_prompt(question, context)},
        ],
        "temperature": 0.4,
    }
    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        r = await client.post(url, headers=headers, json=payload)
        r.raise_for_status()
        data = r.json()
        answer = data["choices"][0]["message"]["content"].strip()
        return {"question": question, "answer": answer}


async def _chat_local(question: str, context: str | None = None) -> dict:
    """Ask the local ai_service (FLAN-T5) chatbot."""
    url = f"{settings.AI_SERVICE_URL}/chat"
    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        r = await client.post(url, json={"question": _build_prompt(question, context)})
        r.raise_for_status()
        data = r.json()
        # Keep the user's original question in the echoed payload, not the
        # context-wrapped prompt the model actually received.
        data["question"] = question
        return data


async def chat(question: str, context: str | None = None) -> dict:
    """Answer a free-text question, guaranteeing a useful reply.

    `context`, when provided, is grounding text retrieved from the database
    (see app/services/knowledge.py) that gets prepended to the prompt so the
    model answers with real facts — a small RAG step.

    Tries the best source available, in order, and only accepts an answer that
    actually looks useful:
      1. GPT, when a usable OpenAI key is set;
      2. the local FLAN-T5 chatbot;
      3. the curated agronomy knowledge base (always works, no deps).

    The local model is small and often returns empty or looping text
    ("a plant with a plant with a plant…"); `_is_low_quality` detects that so we
    drop down to the knowledge base instead of returning garbage to the farmer.
    """
    if settings.OPENAI_API_KEY:
        try:
            result = await _chat_gpt(question, context)
            if not _is_low_quality(result.get("answer")):
                return result
        except httpx.HTTPError:
            # GPT unreachable/unauthorized — fall through.
            pass

    # Authoritative curated answer for the most common questions (headline
    # dashboard prompts etc.) — trusted above the small local model.
    curated = farm_kb.curated_answer(question)
    if curated is not None:
        return {"question": question, "answer": curated}

    # The vetted training corpus is more trustworthy than the tiny, loop-prone
    # local model, so a reasonably confident retrieval match is used directly.
    retrieved, score = dataset_kb.best_answer(question)
    if retrieved and score >= 0.45:
        return {"question": question, "answer": retrieved}

    # Otherwise let the local FLAN-T5 try (with the grounding context), but
    # reject not just looping garbage — also bare echoes of the question, which
    # the small model emits for terse inputs ("rice, sandy soil").
    try:
        result = await _chat_local(question, context)
        answer = result.get("answer")
        if not _is_low_quality(answer) and not _echoes_question(answer, question):
            return result
    except httpx.HTTPError:
        # AI service down — fall through to the offline knowledge base.
        pass

    # Reliable last resort: curated answers → corpus retrieval → safe default.
    # The KB keys off the raw question (it strips the frontend's framing).
    return {"question": question, "answer": farm_kb.answer(question)}
