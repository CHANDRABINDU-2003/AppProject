"""
Plant-disease detection service.
Wraps ML/plant_disease/predict.py:PlantDiseaseClassifier (PyTorch).
Model is loaded lazily on first request and cached for the process lifetime.
"""
import io

from PIL import Image

from app import config
from app.ml_loader import load_module
from app.services.recommendations import advice_for

_classifier = None


def _get_classifier():
    global _classifier
    if _classifier is None:
        mod = load_module(config.PLANT_DISEASE_DIR / "predict.py", "pd_predict")
        _classifier = mod.PlantDiseaseClassifier(config.DISEASE_ARCH)
    return _classifier


def predict(image_bytes: bytes, top_k: int = 3) -> dict:
    clf = _get_classifier()
    # PlantDiseaseClassifier.predict() calls Image.open(...), which accepts a
    # file-like object — so we hand it a BytesIO instead of a file path.
    image = io.BytesIO(image_bytes)
    Image.open(image).verify()          # fail early on a non-image upload
    image.seek(0)

    results = clf.predict(image, top_k=top_k)     # [(name, prob), ...]
    if isinstance(results, tuple):                # top_k == 1 returns a single tuple
        results = [results]

    best_name, best_prob = results[0]
    return {
        "disease": best_name,
        "confidence": float(best_prob),
        "recommendation": advice_for(best_name),
        "top_k": [{"disease": n, "confidence": float(p)} for n, p in results],
    }
