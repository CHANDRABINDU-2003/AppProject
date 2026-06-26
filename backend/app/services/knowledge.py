"""
Knowledge retrieval — the "Database Search → Context" step that runs BEFORE the
FLAN-T5 chatbot. This is a small Retrieval-Augmented Generation (RAG) layer.

Flow (see app/routes/assistant.py):

    Question
        ↓
    Database Search   ← this module
        ↓
    Context
        ↓
    FLAN-T5
        ↓
    Answer

We pull two kinds of grounding into the context:

  1. Curated reference facts from the master tables (crop / disease / fertilizer)
     that the question mentions by name.
  2. The asking farmer's own latest results — their most recent disease
     detection and fertilizer recommendation — so follow-ups like
     "how can I save my crop?" answer about *their* situation.

The result is a plain-text context block the route prepends to the question.
Everything here is best-effort: if nothing matches we return an empty string and
the assistant falls back to answering the bare question.
"""
from __future__ import annotations

from sqlalchemy.orm import Session

from app.models import (
    CropMaster, DiseaseMaster, DiseaseResult, Farmer, FertilizerMaster,
    FertilizerPrediction, Role, User,
)
from app.services import dataset_kb
from app.services.dataset_kb import unframe as _unframe  # strip the UI's mode-framing


def _matches(db: Session, model, question: str, limit: int = 3) -> list:
    """Return master rows whose `name` appears as a word-ish substring of the
    question (case-insensitive). Longer names are matched first so e.g.
    "Cassava Mosaic" wins over the bare crop "Cassava"."""
    q = question.lower()
    rows = db.query(model).all()
    hits = [r for r in rows if r.name and r.name.lower() in q]
    hits.sort(key=lambda r: len(r.name), reverse=True)
    return hits[:limit]


def _reference_context(db: Session, question: str) -> list[str]:
    """Facts from the crop / disease / fertilizer master tables mentioned in the
    question."""
    parts: list[str] = []

    for d in _matches(db, DiseaseMaster, question):
        block = f"Disease: {d.name}"
        if d.symptoms:
            block += f"\nSymptoms: {d.symptoms}"
        if d.solution:
            block += f"\nSolution: {d.solution}"
        parts.append(block)

    for c in _matches(db, CropMaster, question):
        block = f"Crop: {c.name}"
        if c.description:
            block += f"\nAbout: {c.description}"
        if c.season:
            block += f"\nSeason: {c.season}"
        if c.water_requirement:
            block += f"\nWater requirement: {c.water_requirement}"
        parts.append(block)

    for fz in _matches(db, FertilizerMaster, question):
        block = f"Fertilizer: {fz.name}"
        if fz.used_for:
            block += f"\nUsed for: {fz.used_for}"
        parts.append(block)

    return parts


def _farmer_context(db: Session, user: User) -> list[str]:
    """The asking farmer's own latest disease + fertilizer results, so the
    assistant can reason about *their* current situation."""
    prof = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    if not prof:
        return []

    parts: list[str] = []

    latest_disease = (
        db.query(DiseaseResult)
        .filter(DiseaseResult.farmer_id == prof.id)
        .order_by(DiseaseResult.created_at.desc())
        .first()
    )
    if latest_disease and latest_disease.disease_name:
        conf = latest_disease.confidence or 0.0
        block = (
            "Latest Disease Detection:\n"
            f"Disease: {latest_disease.disease_name}\n"
            f"Confidence: {round(conf * 100)}%"
        )
        # If we have a curated treatment for that disease, fold it in.
        master = (
            db.query(DiseaseMaster)
            .filter(DiseaseMaster.name.ilike(f"%{latest_disease.disease_name}%"))
            .first()
        )
        if master and master.solution:
            block += f"\nRecommended treatment: {master.solution}"
        parts.append(block)

    latest_fert = (
        db.query(FertilizerPrediction)
        .filter(FertilizerPrediction.farmer_id == prof.id)
        .order_by(FertilizerPrediction.created_at.desc())
        .first()
    )
    if latest_fert and latest_fert.predicted_fertilizer:
        conf = latest_fert.confidence or 0.0
        block = (
            "Latest Fertilizer Recommendation:\n"
            f"Fertilizer: {latest_fert.predicted_fertilizer}\n"
            f"Confidence: {round(conf * 100)}%"
        )
        master = (
            db.query(FertilizerMaster)
            .filter(FertilizerMaster.name.ilike(f"%{latest_fert.predicted_fertilizer}%"))
            .first()
        )
        if master and master.used_for:
            block += f"\nUsed for: {master.used_for}"
        parts.append(block)

    return parts


def _retrieved_context(question: str) -> list[str]:
    """The closest real answer from the training corpus, when confident — gives
    the model (and the GPT path) a vetted fact to anchor on."""
    retrieved, score = dataset_kb.best_answer(question)
    if retrieved and score >= 0.30:
        return [f"Reference answer: {retrieved}"]
    return []


def build_context(db: Session, user: User, question: str) -> str:
    """Assemble the grounding context for a question, or '' if nothing matched.

    Combines, in priority order:
      • curated reference facts from the master tables the question names;
      • the farmer's own latest disease + fertilizer results (farmers only);
      • the closest vetted Q&A from the training corpus.
    """
    question = _unframe(question)
    parts = _reference_context(db, question)
    if user.role == Role.farmer:
        parts += _farmer_context(db, user)
    parts += _retrieved_context(question)
    return "\n\n".join(parts)
