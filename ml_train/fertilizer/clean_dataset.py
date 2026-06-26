"""
Step 1: clean fertilizer_recommendation.csv ONCE and cache it.

Run whenever the raw CSV changes:

    python ML/fertilizer/clean_dataset.py

Writes reusable artifacts into ML/fertilizer/data/processed/:
    * fertilizer_clean.parquet  -> fast to reload, used by training
    * fertilizer_clean.csv      -> human-readable cleaned dataset

train_xgboost.py reads the parquet directly, so we never re-clean before
training.
"""

import pandas as pd

import config


def main() -> None:
    config.ensure_dirs()

    if not config.RAW_CSV.exists():
        raise FileNotFoundError(f"Raw dataset not found at {config.RAW_CSV}.")

    print(f"Loading raw dataset from {config.RAW_CSV} ...")
    df = pd.read_csv(config.RAW_CSV)
    print(f"  rows in raw file: {len(df):,}")

    # Tidy column names (strip stray whitespace).
    df.columns = [c.strip() for c in df.columns]

    # Keep only the columns we model with (features + target).
    keep = config.FEATURE_COLS + [config.TARGET_COL]
    missing = [c for c in keep if c not in df.columns]
    if missing:
        raise ValueError(f"Expected columns missing from CSV: {missing}")
    df = df[keep]

    # --- clean text columns ---------------------------------------------- #
    for col in config.CATEGORICAL_FEATURES + [config.TARGET_COL]:
        df[col] = df[col].astype(str).str.strip()

    # --- coerce numeric columns; bad values become NaN ------------------- #
    for col in config.NUMERIC_FEATURES:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    before = len(df)

    # Drop rows missing the target (can't learn from them).
    df = df[df[config.TARGET_COL].notna() & (df[config.TARGET_COL] != "")]

    # Impute any missing numeric values with the column median (robust to
    # outliers). XGBoost can handle NaN natively, but imputing keeps the saved
    # data clean and predictions deterministic.
    for col in config.NUMERIC_FEATURES:
        if df[col].isna().any():
            df[col] = df[col].fillna(df[col].median())

    # Fill any missing categorical values with an explicit "Unknown" category.
    for col in config.CATEGORICAL_FEATURES:
        df[col] = df[col].replace({"nan": "Unknown", "": "Unknown"}).fillna(
            "Unknown"
        )

    # Drop exact duplicate rows.
    df = df.drop_duplicates().reset_index(drop=True)

    print(f"  rows after cleaning: {len(df):,}  (removed {before - len(df):,})")
    print("  class distribution:")
    for cls, n in df[config.TARGET_COL].value_counts().items():
        print(f"    {cls:<16} {n:,}")

    # --- persist ---------------------------------------------------------- #
    df.to_parquet(config.CLEAN_PARQUET, index=False)
    df.to_csv(config.CLEAN_CSV, index=False)

    print("\nSaved cached artifacts:")
    print(f"  {config.CLEAN_PARQUET}")
    print(f"  {config.CLEAN_CSV}")
    print("\nDone. Now run:  python ML/fertilizer/train_xgboost.py")


if __name__ == "__main__":
    main()
