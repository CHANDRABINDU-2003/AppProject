"""
Central configuration for the fertilizer recommendation ML pipeline (XGBoost).

All paths derive from this file's location, so the project can be moved or run
from any working directory without breaking.
"""

from pathlib import Path

# --------------------------------------------------------------------------- #
# Paths
# --------------------------------------------------------------------------- #
FERT_DIR = Path(__file__).resolve().parent          # ML/fertilizer
ML_DIR = FERT_DIR.parent                             # ML
PROJECT_DIR = ML_DIR.parent                          # repo root

# Raw input dataset
RAW_CSV = PROJECT_DIR / "fertilizer_recommendation.csv"

# Cleaned data, written ONCE by clean_dataset.py and reused by training.
DATA_DIR = FERT_DIR / "data"
PROCESSED_DIR = DATA_DIR / "processed"
CLEAN_PARQUET = PROCESSED_DIR / "fertilizer_clean.parquet"
CLEAN_CSV = PROCESSED_DIR / "fertilizer_clean.csv"

# Where the trained model bundle is saved (model + preprocessing + label map).
MODELS_DIR = FERT_DIR / "models"
MODEL_PATH = MODELS_DIR / "fertilizer_xgb.joblib"
METRICS_PATH = MODELS_DIR / "metrics.json"

# --------------------------------------------------------------------------- #
# Columns
# --------------------------------------------------------------------------- #
TARGET_COL = "Recommended_Fertilizer"

CATEGORICAL_FEATURES = [
    "Soil_Type",
    "Crop_Type",
    "Crop_Growth_Stage",
    "Season",
    "Irrigation_Type",
    "Previous_Crop",
    "Region",
]

NUMERIC_FEATURES = [
    "Soil_pH",
    "Soil_Moisture",
    "Organic_Carbon",
    "Electrical_Conductivity",
    "Nitrogen_Level",
    "Phosphorus_Level",
    "Potassium_Level",
    "Temperature",
    "Humidity",
    "Rainfall",
    "Fertilizer_Used_Last_Season",
    "Yield_Last_Season",
]

FEATURE_COLS = CATEGORICAL_FEATURES + NUMERIC_FEATURES

# --------------------------------------------------------------------------- #
# Training settings
# --------------------------------------------------------------------------- #
TEST_SPLIT = 0.2
SEED = 42

# XGBoost hyper-parameters (sensible defaults for this size of dataset).
XGB_PARAMS = {
    "n_estimators": 400,
    "max_depth": 6,
    "learning_rate": 0.1,
    "subsample": 0.9,
    "colsample_bytree": 0.9,
    "reg_lambda": 1.0,
    "min_child_weight": 1,
    "objective": "multi:softprob",
    "eval_metric": "mlogloss",
    "tree_method": "hist",
    "random_state": SEED,
    "n_jobs": -1,
}


def ensure_dirs() -> None:
    """Create all output directories if they don't already exist."""
    for d in (DATA_DIR, PROCESSED_DIR, MODELS_DIR):
        d.mkdir(parents=True, exist_ok=True)
