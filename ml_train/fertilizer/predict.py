"""
Step 3: load the saved XGBoost bundle and recommend a fertilizer.

NO retraining -- the model is loaded from disk
(ML/fertilizer/models/fertilizer_xgb.joblib).

Run the built-in demo:
    python ML/fertilizer/predict.py

Or import it from other code (e.g. the FastAPI service):
    from ML.fertilizer.predict import FertilizerRecommender
    rec = FertilizerRecommender()
    print(rec.predict(sample))            # -> "Urea"
    print(rec.predict_proba(sample))      # -> {"Urea": 0.62, "DAP": 0.21, ...}
"""

import joblib
import pandas as pd

import config


class FertilizerRecommender:
    """Loads the trained pipeline once and serves predictions."""

    def __init__(self, model_path=None):
        model_path = model_path or config.MODEL_PATH
        if not config.MODEL_PATH.exists():
            raise FileNotFoundError(
                f"No trained model at {config.MODEL_PATH}. Run:  "
                "python ML/fertilizer/train_xgboost.py  first."
            )
        bundle = joblib.load(model_path)
        self.pipeline = bundle["pipeline"]
        self.label_encoder = bundle["label_encoder"]
        self.feature_cols = bundle["feature_cols"]

    def _to_frame(self, sample) -> pd.DataFrame:
        """Accept a dict (one row) or list of dicts; return an ordered frame."""
        if isinstance(sample, dict):
            sample = [sample]
        df = pd.DataFrame(sample)
        missing = [c for c in self.feature_cols if c not in df.columns]
        if missing:
            raise ValueError(f"Missing required features: {missing}")
        return df[self.feature_cols]

    def predict(self, sample):
        """Return the recommended fertilizer name(s)."""
        X = self._to_frame(sample)
        idx = self.pipeline.predict(X)
        names = self.label_encoder.inverse_transform(idx)
        return names[0] if len(names) == 1 else list(names)

    def predict_proba(self, sample):
        """Return {fertilizer: probability} for the first sample, sorted."""
        X = self._to_frame(sample)
        proba = self.pipeline.predict_proba(X)[0]
        pairs = sorted(
            zip(self.label_encoder.classes_, proba),
            key=lambda kv: kv[1],
            reverse=True,
        )
        return {name: round(float(p), 4) for name, p in pairs}


# A realistic example row (matches the dataset's columns/values).
DEMO_SAMPLE = {
    "Soil_Type": "Clay",
    "Soil_pH": 6.07,
    "Soil_Moisture": 34.98,
    "Organic_Carbon": 0.32,
    "Electrical_Conductivity": 1.87,
    "Nitrogen_Level": 61,
    "Phosphorus_Level": 44,
    "Potassium_Level": 84,
    "Temperature": 19.84,
    "Humidity": 83.31,
    "Rainfall": 1693.22,
    "Crop_Type": "Cotton",
    "Crop_Growth_Stage": "Harvest",
    "Season": "Kharif",
    "Irrigation_Type": "Canal",
    "Previous_Crop": "Wheat",
    "Region": "South",
    "Fertilizer_Used_Last_Season": 297.15,
    "Yield_Last_Season": 1.19,
}


def main() -> None:
    rec = FertilizerRecommender()
    print("Sample input:")
    for k, v in DEMO_SAMPLE.items():
        print(f"  {k}: {v}")
    print(f"\nRecommended fertilizer: {rec.predict(DEMO_SAMPLE)}")
    print("\nClass probabilities:")
    for name, p in rec.predict_proba(DEMO_SAMPLE).items():
        print(f"  {name:<16} {p:.4f}")


if __name__ == "__main__":
    main()
