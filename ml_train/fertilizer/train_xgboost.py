"""
Step 2: train an XGBoost classifier on the cleaned fertilizer data and SAVE it.

Run AFTER clean_dataset.py:

    python ML/fertilizer/train_xgboost.py

Saves a single self-contained bundle to ML/fertilizer/models/fertilizer_xgb.joblib
containing:
    * the fitted preprocessing pipeline (one-hot + scaling)
    * the trained XGBoost model
    * the label encoder (maps class index <-> fertilizer name)

Because everything is saved to disk, you train ONCE. predict.py loads the
bundle and never retrains.
"""

import json

import joblib
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.metrics import accuracy_score, classification_report, f1_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder, OneHotEncoder, StandardScaler
from xgboost import XGBClassifier

import config


def load_clean_data() -> pd.DataFrame:
    if not config.CLEAN_PARQUET.exists():
        raise FileNotFoundError(
            "Cleaned data not found. Run:  "
            "python ML/fertilizer/clean_dataset.py  first."
        )
    df = pd.read_parquet(config.CLEAN_PARQUET)
    print(f"Loaded {len(df):,} cleaned rows")
    return df


def build_pipeline(num_classes: int) -> Pipeline:
    """Preprocessing (one-hot categoricals + scale numerics) -> XGBoost."""
    preprocessor = ColumnTransformer(
        transformers=[
            (
                "cat",
                OneHotEncoder(handle_unknown="ignore"),
                config.CATEGORICAL_FEATURES,
            ),
            ("num", StandardScaler(), config.NUMERIC_FEATURES),
        ]
    )
    model = XGBClassifier(num_class=num_classes, **config.XGB_PARAMS)
    return Pipeline([("pre", preprocessor), ("clf", model)])


def main() -> None:
    config.ensure_dirs()

    df = load_clean_data()
    X = df[config.FEATURE_COLS]
    y_raw = df[config.TARGET_COL]

    # Encode target labels to integers (XGBoost needs numeric classes).
    label_encoder = LabelEncoder()
    y = label_encoder.fit_transform(y_raw)
    print(f"Classes: {list(label_encoder.classes_)}")

    # Stratified split keeps the class balance in train and test.
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=config.TEST_SPLIT, random_state=config.SEED, stratify=y
    )
    print(f"Train: {len(X_train):,}  Test: {len(X_test):,}")

    pipeline = build_pipeline(num_classes=len(label_encoder.classes_))

    print("\nTraining XGBoost ...")
    pipeline.fit(X_train, y_train)

    # --- evaluate --------------------------------------------------------- #
    y_pred = pipeline.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    macro_f1 = f1_score(y_test, y_pred, average="macro")
    report = classification_report(
        y_test, y_pred, target_names=label_encoder.classes_
    )
    print(f"\nTest accuracy : {accuracy:.4f}")
    print(f"Macro F1      : {macro_f1:.4f}")
    print("\nClassification report:\n" + report)

    # --- persist the full bundle ----------------------------------------- #
    bundle = {
        "pipeline": pipeline,
        "label_encoder": label_encoder,
        "feature_cols": config.FEATURE_COLS,
        "categorical_features": config.CATEGORICAL_FEATURES,
        "numeric_features": config.NUMERIC_FEATURES,
    }
    joblib.dump(bundle, config.MODEL_PATH)

    metrics = {
        "accuracy": round(float(accuracy), 4),
        "macro_f1": round(float(macro_f1), 4),
        "n_train": len(X_train),
        "n_test": len(X_test),
        "classes": list(label_encoder.classes_),
    }
    config.METRICS_PATH.write_text(json.dumps(metrics, indent=2))

    print(f"\nSaved trained model bundle to {config.MODEL_PATH}")
    print(f"Saved metrics to {config.METRICS_PATH}")
    print("\nDone. Run:  python ML/fertilizer/predict.py  to make predictions.")


if __name__ == "__main__":
    main()
