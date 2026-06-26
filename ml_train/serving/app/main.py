"""
AgriPulse AI service — FastAPI entry point ("ML Layer" in the architecture).
Serves three trained models:
  • /predict/crop       -> plant-disease CNN  (PyTorch, EfficientNet-B0)
  • /predict/fertilizer -> fertilizer recommender (XGBoost)
  • /chat               -> agriculture chatbot (FLAN-T5)

Run from the ml_train/serving/ folder:
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8001

The core backend (../../backend) calls these endpoints; it does NOT load the
models itself. Models load lazily on first request, so startup is instant.
"""
import threading

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware

from app.schemas import (
    ChatRequest, ChatResponse, DiseasePrediction, FertilizerFeatures,
    FertilizerPrediction,
)
from app.services import chatbot_service, disease_service, fertilizer_service

app = FastAPI(title="AgriPulse AI", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def _warm_models() -> None:
    """Preload the models in a background thread.

    Models used to load lazily on their first request, which made the first
    disease/fertilizer/chat call painfully slow (cold CNN + XGBoost + FLAN-T5
    load on CPU). Warming them here keeps startup instant while making the
    first real request fast. Failures are ignored — the lazy path still works.
    """
    def _load():
        for getter in (
            disease_service._get_classifier,
            fertilizer_service._get_recommender,
            chatbot_service._get_bot,
        ):
            try:
                getter()
            except Exception:
                pass  # model missing/untrained — the request path reports it

    threading.Thread(target=_load, name="model-warmup", daemon=True).start()


@app.get("/health", tags=["health"])
def health():
    return {"status": "ok", "service": "agripulse-ai"}


@app.post("/predict/crop", response_model=DiseasePrediction, tags=["disease"])
async def predict_crop(image: UploadFile = File(...), note: str = Form("")):
    """Classify a crop-leaf image and return disease + treatment advice."""
    image_bytes = await image.read()
    try:
        # Run the blocking CPU inference in a threadpool so it doesn't freeze
        # the event loop (which would stall every other concurrent request).
        return await run_in_threadpool(disease_service.predict, image_bytes)
    except FileNotFoundError as e:
        raise HTTPException(status_code=503, detail=str(e))     # model not trained
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Could not process image: {e}")


@app.post("/predict/fertilizer", response_model=FertilizerPrediction, tags=["fertilizer"])
def predict_fertilizer(features: FertilizerFeatures):
    """Recommend a fertilizer from soil + crop + weather features."""
    try:
        return fertilizer_service.predict(features.model_dump())
    except FileNotFoundError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Prediction failed: {e}")


@app.post("/chat", response_model=ChatResponse, tags=["chatbot"])
def chat(req: ChatRequest):
    """Answer a free-text agriculture question."""
    try:
        return ChatResponse(question=req.question, answer=chatbot_service.answer(req.question))
    except FileNotFoundError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Chat failed: {e}")
