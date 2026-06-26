# Fertilizer Recommendation — XGBoost Pipeline

Trains an [XGBoost](https://xgboost.readthedocs.io/) classifier on
`fertilizer_recommendation.csv` to recommend a fertilizer from soil, crop,
weather and history features.

Three independent stages so you clean and train **once**, then reuse the cached
data and the saved model forever:

```
clean_dataset.py  ->  train_xgboost.py  ->  predict.py
   (clean once)        (train once)          (load & predict, no retrain)
```

## Folder layout

```
ML/fertilizer/
├── config.py            # paths, feature lists, XGBoost hyper-parameters
├── clean_dataset.py     # Step 1: clean raw CSV -> cached parquet/csv
├── train_xgboost.py     # Step 2: train XGBoost -> saved model bundle
├── predict.py           # Step 3: load saved model & recommend (no retrain)
├── requirements.txt
├── data/
│   └── processed/       # cached cleaned data (created by step 1)
│       ├── fertilizer_clean.parquet
│       └── fertilizer_clean.csv
└── models/              # saved artifacts (created by step 2)
    ├── fertilizer_xgb.joblib   # pipeline + label encoder (the trained model)
    └── metrics.json            # accuracy / F1 / class list
```

## Setup

```bash
pip install -r ML/fertilizer/requirements.txt
```

## Usage

```bash
# 1. Clean the raw CSV once. Re-run only if the CSV changes.
python ML/fertilizer/clean_dataset.py

# 2. Train XGBoost once. Model saved to models/fertilizer_xgb.joblib.
python ML/fertilizer/train_xgboost.py

# 3. Recommend a fertilizer — loads the saved model, never retrains.
python ML/fertilizer/predict.py
```

## What gets stored (so you don't retrain)

- `models/fertilizer_xgb.joblib` is a single bundle holding the fitted
  preprocessing pipeline (one-hot encoding + scaling), the trained XGBoost
  model, and the label encoder (class index <-> fertilizer name).
- `predict.py` / `FertilizerRecommender` just load this file — no retraining.

## Current results

~87% test accuracy (macro-F1 ~0.73). The `SSP` class is rare (182 rows) and
predicted poorly — see "Improving the model" below.

## Use from other code

```python
from ML.fertilizer.predict import FertilizerRecommender

rec = FertilizerRecommender()         # loads the saved model once
sample = { "Soil_Type": "Clay", "Soil_pH": 6.07, ...full feature row... }
print(rec.predict(sample))            # -> "MOP"
print(rec.predict_proba(sample))      # -> {"MOP": 0.97, "NPK": 0.01, ...}
```

## Improving the model

Edit `config.py`:

- `XGB_PARAMS` — tune `n_estimators`, `max_depth`, `learning_rate`, etc.
- The dataset is imbalanced (`SSP` is rare). Options: add class weights via
  `sample_weight` in training, oversample minority classes, or collect more
  `SSP` examples.
