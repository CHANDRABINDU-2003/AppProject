"""
AI service configuration — where the trained models live on disk.
All paths derive from this file so it works regardless of working directory.

Layout:
    ml_train/
      ├── serving/app/config.py   ← this file
      ├── plant_disease/          ← PyTorch CNN + its models/
      ├── fertilizer/             ← XGBoost bundle + its models/
      └── chatbot/                ← FLAN-T5 (inference.py, config.py, models/)
"""
from pathlib import Path

# serving/app/config.py -> serving/app -> serving -> ml_train (the ML root)
ML_ROOT = Path(__file__).resolve().parents[2]

# Plant-disease classifier (PyTorch). Two trained archs are available:
#   "efficientnet_b0" (higher accuracy) | "mobilenet_v3" (lighter/faster).
PLANT_DISEASE_DIR = ML_ROOT / "plant_disease"
DISEASE_ARCH = "efficientnet_b0"

# Fertilizer recommender (XGBoost bundle).
FERTILIZER_DIR = ML_ROOT / "fertilizer"

# Chatbot (FLAN-T5). inference.py + config.py live under ml_train/chatbot/.
CHATBOT_DIR = ML_ROOT / "chatbot"
