"""
Agriculture chatbot service.
Wraps ML/inference.py:AgriChatbot (fine-tuned FLAN-T5).
"""
from app import config
from app.ml_loader import load_module

_bot = None


def _get_bot():
    global _bot
    if _bot is None:
        mod = load_module(config.CHATBOT_DIR / "inference.py", "agri_inference")
        _bot = mod.AgriChatbot()
    return _bot


def answer(question: str) -> str:
    return _get_bot().answer(question)
