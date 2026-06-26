"""
Extract the crop / disease / fertilizer vocabulary that ACTUALLY appears in the
agriculture chatbot training dataset, and dump it to small reference CSVs.

Why: the assistant grounds its answers in master tables (crop_master,
disease_master, fertilizer_master). This script tells us which of those terms
the training corpus really talks about, so the master tables — and the
retrieval knowledge base in backend/app/services/dataset_kb.py — stay aligned
with the data the model was trained on.

Run it from anywhere (paths are derived from this file's location):

    python scripts/extract_knowledge.py

Outputs (written next to this script):

    scripts/crops.csv
    scripts/diseases.csv
    scripts/fertilizers.csv

No third-party dependencies — pure standard library, so it runs in any venv.
"""
from __future__ import annotations

import csv
from pathlib import Path

# ── Paths (derived, so the script is location-independent) ───────────────────
HERE = Path(__file__).resolve().parent
PROJECT_DIR = HERE.parent
# The raw training corpus (question, answers). Falls back to the cleaned copy.
RAW_CSV = PROJECT_DIR / "ml_train" / "agri_chatbot.csv"
CLEAN_CSV = (
    PROJECT_DIR / "ml_train" / "chatbot" / "data" / "processed" / "agri_chatbot_clean.csv"
)

# ── Vocabulary to look for ───────────────────────────────────────────────────
# Multi-word phrases come first so e.g. "cassava bacterial blight" is detected
# as a disease before the bare crop "cassava" is counted.
CROP_KEYWORDS = [
    "rice", "wheat", "maize", "corn", "potato", "tomato", "cabbage", "carrot",
    "beans", "cassava", "banana", "mango", "pepper", "cucumber", "groundnut",
    "soybean", "cotton", "onion", "chilli", "sugarcane",
]
DISEASE_KEYWORDS = [
    "cassava bacterial blight", "cassava mosaic", "banana bacterial wilt",
    "bacterial leaf spot", "late blight", "early blight", "leaf mold",
    "fusarium wilt", "bacterial wilt", "powdery mildew", "downy mildew",
    "anthracnose", "root rot", "common scab", "leaf curl", "mosaic", "blight",
    "rust", "wilt",
]
FERTILIZER_KEYWORDS = [
    "urea", "dap", "npk", "compost", "manure", "ammonium nitrate",
    "ammonium sulphate", "ammonium sulfate", "triple superphosphate",
    "superphosphate", "potassium", "nitrogen", "phosphorus",
]


def _read_rows() -> list[str]:
    """Return one lower-cased 'question + answer' string per dataset row.

    Tolerates either the raw CSV ('answers' column) or the cleaned CSV
    ('answer' column), and degrades to whichever file exists.
    """
    path = RAW_CSV if RAW_CSV.exists() else CLEAN_CSV
    if not path.exists():
        raise FileNotFoundError(
            f"No dataset found at {RAW_CSV} or {CLEAN_CSV}. "
            "Run the ML data pipeline first."
        )
    print(f"Reading dataset: {path}")
    texts: list[str] = []
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        # The answer column is 'answers' in the raw file, 'answer' in the clean one.
        answer_col = "answers" if "answers" in (reader.fieldnames or []) else "answer"
        for row in reader:
            q = str(row.get("question", ""))
            a = str(row.get(answer_col, ""))
            texts.append(f"{q} {a}".lower())
    print(f"  rows: {len(texts)}")
    return texts


def _extract(texts: list[str], keywords: list[str]) -> list[tuple[str, int]]:
    """Count how many rows mention each keyword; return only the ones that hit,
    as (name, hit_count) sorted by frequency (most-discussed first)."""
    counts = {kw: 0 for kw in keywords}
    for text in texts:
        for kw in keywords:
            if kw in text:
                counts[kw] += 1
    found = [(kw, c) for kw, c in counts.items() if c > 0]
    found.sort(key=lambda x: x[1], reverse=True)
    return found


def _save(rows: list[tuple[str, int]], filename: str) -> None:
    out = HERE / filename
    with open(out, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["name", "mentions"])
        for name, count in rows:
            # Title-case multi-word names for clean display ("late blight" → "Late Blight").
            writer.writerow([name.title(), count])
    print(f"  wrote {len(rows):>3} rows -> {out.relative_to(PROJECT_DIR)}")


def main() -> None:
    texts = _read_rows()

    print("\nExtracting crops…")
    crops = _extract(texts, CROP_KEYWORDS)
    print("  found:", [name for name, _ in crops])
    _save(crops, "crops.csv")

    print("\nExtracting diseases…")
    diseases = _extract(texts, DISEASE_KEYWORDS)
    print("  found:", [name for name, _ in diseases])
    _save(diseases, "diseases.csv")

    print("\nExtracting fertilizers…")
    fertilizers = _extract(texts, FERTILIZER_KEYWORDS)
    print("  found:", [name for name, _ in fertilizers])
    _save(fertilizers, "fertilizers.csv")

    print("\n✅ Done. Reference CSVs written to scripts/.")


if __name__ == "__main__":
    main()
