"""
Central configuration for the agriculture chatbot ML pipeline.

Every path is derived from this file's location so the project can be moved
or run from any working directory without breaking.
"""

from pathlib import Path

# --------------------------------------------------------------------------- #
# Paths
# --------------------------------------------------------------------------- #
ML_DIR = Path(__file__).resolve().parent
PROJECT_DIR = ML_DIR.parent

# Raw input dataset (the file produced by download_dataset.py)
RAW_CSV = PROJECT_DIR / "agri_chatbot.csv"

# Cleaned / processed artifacts. These are written ONCE by clean_dataset.py
# and reused by training + inference so we never re-clean or re-train blindly.
DATA_DIR = ML_DIR / "data"
PROCESSED_DIR = DATA_DIR / "processed"
CLEAN_CSV = PROCESSED_DIR / "agri_chatbot_clean.csv"
TRAIN_PARQUET = PROCESSED_DIR / "train.parquet"
VAL_PARQUET = PROCESSED_DIR / "val.parquet"

# Where the fine-tuned model + tokenizer are saved.
MODELS_DIR = ML_DIR / "models"
MODEL_DIR = MODELS_DIR / "flan_t5_agri"

# --------------------------------------------------------------------------- #
# Column names in the source CSV
# --------------------------------------------------------------------------- #
QUESTION_COL = "question"
ANSWER_COL = "answers"

# --------------------------------------------------------------------------- #
# Model / training hyper-parameters
# --------------------------------------------------------------------------- #
# flan-t5-small (~80M) is the sensible default for a laptop. Bump to
# "google/flan-t5-base" if you have a GPU and want better answers.
BASE_MODEL = "google/flan-t5-small"

# Prompt template. FLAN-T5 was instruction-tuned, so giving it an explicit
# instruction at train AND inference time improves answer quality.
PROMPT_PREFIX = "Answer this agriculture question: "

# Shorter sequences => less memory. 64/96 is plenty for short Q&A pairs and
# noticeably cheaper than 96/128 on the Apple MPS GPU.
MAX_INPUT_LENGTH = 64      # tokens for the question
MAX_TARGET_LENGTH = 96     # tokens for the answer

NUM_EPOCHS = 3
# Memory-safe defaults for Apple MPS: tiny per-step batch, but accumulate
# gradients so the EFFECTIVE batch size is BATCH_SIZE * GRAD_ACCUM_STEPS = 8.
BATCH_SIZE = 1
GRAD_ACCUM_STEPS = 8
LEARNING_RATE = 3e-4       # a touch higher works well for LoRA
VAL_SPLIT = 0.05           # 5% held out for evaluation
SEED = 42

# --------------------------------------------------------------------------- #
# LoRA (PEFT) configuration
# --------------------------------------------------------------------------- #
# LoRA freezes the base model and trains small low-rank adapters instead, using
# ~5-10x less memory than full fine-tuning. After training we merge the adapter
# back into the base weights and save a plain model, so inference stays simple.
USE_LORA = True
LORA_R = 16                # rank of the low-rank update
LORA_ALPHA = 32            # scaling factor (usually 2 * r)
LORA_DROPOUT = 0.05
# Attention projections in T5. These are the standard LoRA targets for T5.
LORA_TARGET_MODULES = ["q", "v"]


def ensure_dirs() -> None:
    """Create all output directories if they don't already exist."""
    for d in (DATA_DIR, PROCESSED_DIR, MODELS_DIR):
        d.mkdir(parents=True, exist_ok=True)
