"""
Assistant / chatbot route — available to ALL logged-in roles.

Before forwarding a question to the AI service's FLAN-T5 chatbot we run a small
Retrieval-Augmented Generation (RAG) step: we search the knowledge master tables
(crop / disease / fertilizer) and the farmer's own latest results, then prepend
that as grounding context.

    Question → Database Search → Context → FLAN-T5 → Answer

Also serves role-specific suggested questions for the dashboards.
"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models import Role, User
from app.services import ai_client, knowledge

router = APIRouter(prefix="/assistant", tags=["assistant"])


class ChatIn(BaseModel):
    question: str


class ChatOut(BaseModel):
    question: str
    answer: str


class SuggestedQuestionsOut(BaseModel):
    questions: list[str]


# Quick-start prompts shown on each dashboard so users know what to ask.
_FARMER_QUESTIONS = [
    "What fertilizer should I use?",
    "How can I treat crop disease?",
    "Best crops for this season?",
    "How much water does rice need?",
]
_SELLER_QUESTIONS = [
    "Which crops have high demand?",
    "Market price prediction?",
    "Best-selling fertilizers?",
    "Which products should I stock next season?",
]
_ANALYST_QUESTIONS = [
    "Which regions report the most crop disease?",
    "What are the top fertilizer recommendations?",
    "Which crops are trending this season?",
]


@router.post("/chat", response_model=ChatOut)
async def chat(
    payload: ChatIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    # 1) Database search → context (RAG grounding), then 2) ask the model.
    context = knowledge.build_context(db, user, payload.question)
    result = await ai_client.chat(payload.question, context=context)
    return ChatOut(question=payload.question, answer=result.get("answer", ""))


@router.get("/suggested-questions", response_model=SuggestedQuestionsOut)
def suggested_questions(user: User = Depends(get_current_user)):
    """Role-specific quick-start prompts for the dashboard chat box."""
    by_role = {
        Role.farmer: _FARMER_QUESTIONS,
        Role.seller: _SELLER_QUESTIONS,
        Role.analyst: _ANALYST_QUESTIONS,
    }
    return SuggestedQuestionsOut(questions=by_role.get(user.role, _FARMER_QUESTIONS))
