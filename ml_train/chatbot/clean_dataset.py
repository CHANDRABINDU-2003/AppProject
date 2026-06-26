"""
Step 1 of the pipeline: clean the raw agri_chatbot.csv ONCE and cache it.

Run this whenever the raw CSV changes:

    python ML/clean_dataset.py

It writes three reusable artifacts into ML/data/processed/:
    * agri_chatbot_clean.csv  -> human-readable cleaned dataset
    * train.parquet           -> training split (fast to reload)
    * val.parquet             -> validation split

train_flan_t5.py reads the parquet files directly, so we never pay the
cleaning cost again and never have to re-run this before training.
"""

import re

import pandas as pd

import config


# --------------------------------------------------------------------------- #
# Text cleaning helpers
# --------------------------------------------------------------------------- #
def normalise_text(text: str) -> str:
    """Collapse whitespace, strip stray quotes and tidy punctuation spacing."""
    if not isinstance(text, str):
        return ""
    text = text.replace(" ", " ")          # non-breaking spaces
    text = re.sub(r"\s+", " ", text)            # collapse runs of whitespace
    text = text.strip().strip('"').strip()      # outer quotes + whitespace
    text = re.sub(r"\s+([?.!,;:])", r"\1", text)  # no space before punctuation
    return text


def clean_question(q: str) -> str:
    q = normalise_text(q)
    if not q:
        return ""
    # Ensure questions end with a question mark so the model sees consistent
    # phrasing. Only add one if it doesn't already end in punctuation.
    if q[-1] not in "?.!":
        q += "?"
    return q


def clean_answer(a: str) -> str:
    a = normalise_text(a)
    if not a:
        return ""
    # Capitalise the first letter for consistent, readable answers.
    return a[0].upper() + a[1:]


def main() -> None:
    config.ensure_dirs()

    if not config.RAW_CSV.exists():
        raise FileNotFoundError(
            f"Raw dataset not found at {config.RAW_CSV}. "
            "Run download_dataset.py first."
        )

    print(f"Loading raw dataset from {config.RAW_CSV} ...")
    df = pd.read_csv(config.RAW_CSV)
    print(f"  rows in raw file: {len(df):,}")

    # Keep only the two columns we care about, renamed to the canonical names.
    df = df.rename(
        columns={config.QUESTION_COL: "question", config.ANSWER_COL: "answer"}
    )[["question", "answer"]]

    # --- clean text ------------------------------------------------------- #
    df["question"] = df["question"].map(clean_question)
    df["answer"] = df["answer"].map(clean_answer)

    # --- drop garbage rows ------------------------------------------------ #
    before = len(df)
    df = df[(df["question"] != "") & (df["answer"] != "")]
    # Remove answers that are too short to be useful (e.g. single stray chars).
    df = df[df["answer"].str.len() >= 2]
    # Drop exact duplicate question/answer pairs.
    df = df.drop_duplicates(subset=["question", "answer"])
    # If the same question maps to several answers, keep the longest (most
    # informative) one so each question is unique for seq2seq training.
    df["__len"] = df["answer"].str.len()
    df = (
        df.sort_values("__len", ascending=False)
        .drop_duplicates(subset=["question"], keep="first")
        .drop(columns="__len")
        .reset_index(drop=True)
    )
    print(f"  rows after cleaning: {len(df):,}  (removed {before - len(df):,})")

    # --- train / val split ------------------------------------------------ #
    df = df.sample(frac=1.0, random_state=config.SEED).reset_index(drop=True)
    n_val = max(1, int(len(df) * config.VAL_SPLIT))
    val_df = df.iloc[:n_val].reset_index(drop=True)
    train_df = df.iloc[n_val:].reset_index(drop=True)

    # --- persist ---------------------------------------------------------- #
    df.to_csv(config.CLEAN_CSV, index=False)
    train_df.to_parquet(config.TRAIN_PARQUET, index=False)
    val_df.to_parquet(config.VAL_PARQUET, index=False)

    print("\nSaved cached artifacts:")
    print(f"  {config.CLEAN_CSV}  ({len(df):,} rows)")
    print(f"  {config.TRAIN_PARQUET}  ({len(train_df):,} rows)")
    print(f"  {config.VAL_PARQUET}  ({len(val_df):,} rows)")
    print("\nDone. You can now run:  python ML/train_flan_t5.py")


if __name__ == "__main__":
    main()
