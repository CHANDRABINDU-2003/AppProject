# AgriPulse — ML (training + serving)

Everything machine-learning lives here: the three model training pipelines and
the FastAPI service that serves the trained models to the backend.

```
ml_train/
├── serving/            # FastAPI "AI service" — loads + serves the 3 models (port 8001)
│   ├── app/
│   │   ├── main.py             # /predict/crop · /predict/fertilizer · /chat
│   │   ├── config.py           # paths to the trained models on disk
│   │   ├── ml_loader.py        # imports each pipeline's predict code in isolation
│   │   └── services/           # disease · fertilizer · chatbot wrappers
│   └── requirements.txt
├── plant_disease/      # PyTorch CNN (EfficientNet-B0 / MobileNet-V3, 15 classes)
│   ├── train.py  evaluate.py  predict.py  dataset.py  models.py  config.py
│   ├── data/processed/         # train/val/test manifests + class_names.json
│   └── models/                 # trained weights (best_model.pt per arch)
├── fertilizer/         # XGBoost recommender
│   ├── train_xgboost.py  predict.py  clean_dataset.py  config.py
│   ├── data/processed/
│   └── models/                 # fertilizer_xgb.joblib + metrics.json
├── chatbot/            # FLAN-T5 (LoRA fine-tuned) farming Q&A
│   ├── train_flan_t5.py  inference.py  clean_dataset.py  config.py
│   ├── data/processed/
│   └── models/flan_t5_agri/    # fine-tuned model + tokenizer
├── archive/PlantVillage/       # raw leaf-image dataset (plant_disease training)
├── agri_chatbot.csv            # raw chatbot Q&A (chatbot training)
├── fertilizer_recommendation.csv  # raw fertilizer dataset (fertilizer training)
└── download_dataset.py         # fetches the chatbot dataset
```

The models are **already trained** (weights are on disk under each pipeline's
`models/`). You only need the training scripts to re-train.

## Serve the models (what the backend talks to)

```bash
cd ml_train/serving
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8001
```

Check: http://localhost:8001/docs · health at `/health`.

`serving/app/config.py` resolves every model path from `ml_train/` (its parent),
so the service finds `plant_disease/`, `fertilizer/` and `chatbot/` automatically.
Models load lazily on first request, so startup is instant.

## Re-train a model (optional)

Each pipeline is self-contained and reads its raw data from `ml_train/`:

```bash
# Chatbot (FLAN-T5)
python chatbot/clean_dataset.py && python chatbot/train_flan_t5.py

# Fertilizer (XGBoost)
python fertilizer/clean_dataset.py && python fertilizer/train_xgboost.py

# Plant disease (PyTorch) — needs archive/PlantVillage/
python plant_disease/prepare_dataset.py && python plant_disease/train.py
```

Each pipeline has its own `requirements.txt`; install in a virtualenv. Use
Python 3.10–3.12 (torch / xgboost wheels lag on 3.13+).
