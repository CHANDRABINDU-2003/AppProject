"""
Fertilizer recommendation service.
Wraps ML/fertilizer/predict.py:FertilizerRecommender (XGBoost bundle).
"""
from app import config
from app.ml_loader import load_module

_recommender = None


def _get_recommender():
    global _recommender
    if _recommender is None:
        mod = load_module(config.FERTILIZER_DIR / "predict.py", "fert_predict")
        _recommender = mod.FertilizerRecommender()
    return _recommender


def predict(features: dict) -> dict:
    rec = _get_recommender()
    name = rec.predict(features)              # e.g. "Urea"
    proba = rec.predict_proba(features)       # {"Urea": 0.62, "DAP": 0.21, ...}
    return {
        "predicted_fertilizer": name,
        "confidence": float(proba.get(name, 0.0)),
        "top_k": dict(list(proba.items())[:5]),
    }
