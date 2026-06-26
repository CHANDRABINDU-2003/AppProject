"""
Central configuration for the plant-disease image classification pipeline.

Two models are trained from the same data:
    * EfficientNet-B0  -> the main / high-accuracy model
    * MobileNetV3-Large -> the lightweight deployment model

All paths derive from this file's location so the project can be moved or run
from any working directory.
"""

from pathlib import Path

# --------------------------------------------------------------------------- #
# Paths
# --------------------------------------------------------------------------- #
PD_DIR = Path(__file__).resolve().parent            # ML/plant_disease
ML_DIR = PD_DIR.parent                              # ML
PROJECT_DIR = ML_DIR.parent                         # repo root

# Raw images. The PlantVillage dataset lives here. NOTE: the archive contains
# an exact nested duplicate at archive/PlantVillage/PlantVillage -- we use only
# the top level and explicitly ignore the nested copy (see IGNORE_DIRS).
DATA_ROOT = PROJECT_DIR / "archive" / "PlantVillage"
IGNORE_DIRS = {"PlantVillage"}                       # the nested duplicate

# Cached manifests, written ONCE by prepare_dataset.py and reused for training.
DATA_DIR = PD_DIR / "data"
PROCESSED_DIR = DATA_DIR / "processed"
TRAIN_MANIFEST = PROCESSED_DIR / "train.csv"
VAL_MANIFEST = PROCESSED_DIR / "val.csv"
TEST_MANIFEST = PROCESSED_DIR / "test.csv"
CLASS_NAMES_JSON = PROCESSED_DIR / "class_names.json"

# Where trained models are saved (one subfolder per architecture).
MODELS_DIR = PD_DIR / "models"

# Supported architectures -> subfolder name for saved weights.
MODEL_DIRS = {
    "efficientnet_b0": MODELS_DIR / "efficientnet_b0",
    "mobilenet_v3": MODELS_DIR / "mobilenet_v3",
}
WEIGHTS_FILENAME = "best_model.pt"      # state_dict + metadata
METRICS_FILENAME = "metrics.json"

# --------------------------------------------------------------------------- #
# Image / data settings
# --------------------------------------------------------------------------- #
VALID_EXTENSIONS = {".jpg", ".jpeg", ".png"}
IMAGE_SIZE = 224                        # both models expect 224x224
# ImageNet normalisation (the pretrained backbones were trained with these).
NORM_MEAN = [0.485, 0.456, 0.406]
NORM_STD = [0.229, 0.224, 0.225]

VAL_SPLIT = 0.15
TEST_SPLIT = 0.15                       # remaining 0.70 is training
SEED = 42

# --------------------------------------------------------------------------- #
# Training settings
# --------------------------------------------------------------------------- #
NUM_EPOCHS = 8
BATCH_SIZE = 32
LEARNING_RATE = 1e-3
WEIGHT_DECAY = 1e-4
NUM_WORKERS = 4
# Classes are imbalanced (e.g. Potato___healthy has ~150 images vs 3200 for
# Tomato YellowLeaf Curl). Weight the loss by inverse class frequency.
USE_CLASS_WEIGHTS = True


def ensure_dirs() -> None:
    """Create all output directories if they don't already exist."""
    dirs = [DATA_DIR, PROCESSED_DIR, MODELS_DIR, *MODEL_DIRS.values()]
    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)
