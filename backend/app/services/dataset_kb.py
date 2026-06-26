"""
Retrieval knowledge base — the assistant's most reliable answer source.

The local FLAN-T5-small model is tiny and frequently returns off-topic or
looping text ("…is a fungus in the family Tomatoes. It is a fungus in the
family Tomatoes."). But the project already ships a curated corpus of ~2,200
real agriculture Q&A pairs (the chatbot's *training* data). Instead of trusting
the weak model to regenerate that knowledge, we retrieve the closest matching
question and return its vetted answer directly.

This is classic TF-IDF retrieval, implemented in pure Python (no pandas /
scikit-learn) so it adds zero dependencies to the core backend:

  • index every dataset question as a TF-IDF vector (built once, cached);
  • embed the incoming question the same way;
  • return the answer of the highest cosine-similarity question, plus a 0–1
    confidence score the caller can threshold on.

If the dataset file is missing the index is simply empty and `best_answer`
returns (None, 0.0) — callers then fall back to their own defaults.
"""
from __future__ import annotations

import csv
import math
import re
from pathlib import Path

# The cleaned Q&A corpus produced by the ML pipeline (question, answer).
# services → app → backend → repo root, then into ml_train/.
_DATASET = (
    Path(__file__).resolve().parents[3]
    / "ml_train" / "chatbot" / "data" / "processed" / "agri_chatbot_clean.csv"
)

_WORD_RE = re.compile(r"[a-z0-9]+")

# The frontend frames questions by mode ("Answer this fertilizer question…: <q>").
# Strip that instruction wrapper so retrieval keys off the farmer's real words.
_FRAMING_RE = re.compile(r"^answer this [\w\s]*?question[\w\s,]*?:\s*", re.IGNORECASE)


def unframe(question: str) -> str:
    """Remove the assistant's mode-framing prefix, if present."""
    return _FRAMING_RE.sub("", question).strip() or question

# Very common words (English + the assistant's own framing words like
# "answer/question/recommend") carry no topical signal, so we drop them.
_STOPWORDS = {
    "a", "an", "the", "is", "are", "was", "were", "be", "been", "being", "of",
    "to", "in", "on", "for", "and", "or", "but", "with", "without", "as", "at",
    "by", "from", "into", "this", "that", "these", "those", "it", "its", "i",
    "you", "your", "my", "me", "we", "our", "they", "them", "their", "he", "she",
    "do", "does", "did", "can", "could", "should", "would", "will", "shall",
    "what", "which", "who", "whom", "how", "when", "where", "why", "whose",
    "there", "here", "than", "then", "so", "if", "about", "tell", "give", "get",
    "please", "answer", "question", "recommend", "recommending", "suggest",
    "suitable", "naming", "likely", "treatment", "help", "need", "want", "use",
}


# Domain "entities" — crop and disease names. When the question names one of
# these, we strongly prefer answers that talk about the SAME crop/disease, so a
# question about rice doesn't get answered with a fact about mango just because
# both share the word "watering". (Mirrors scripts/extract_knowledge.py.)
_ENTITY_VOCAB = {
    "rice", "wheat", "maize", "corn", "potato", "tomato", "cabbage", "carrot",
    "beans", "cassava", "banana", "mango", "pepper", "cucumber", "groundnut",
    "soybean", "cotton", "onion", "chilli", "sugarcane",
    "blight", "mosaic", "wilt", "anthracnose", "rust", "scab", "mildew",
    "mold", "rot", "fusarium",
}


def _tokens(text: str) -> list[str]:
    return [
        w for w in _WORD_RE.findall(text.lower())
        if len(w) > 1 and w not in _STOPWORDS
    ]


class _Index:
    """A cached TF-IDF index over the dataset questions."""

    def __init__(self, questions: list[str], answers: list[str]):
        self.answers = answers
        n = len(questions)

        doc_tokens = [_tokens(q) for q in questions]

        # Document frequency → inverse document frequency (smoothed).
        df: dict[str, int] = {}
        for toks in doc_tokens:
            for t in set(toks):
                df[t] = df.get(t, 0) + 1
        self.idf = {t: math.log((n + 1) / (c + 1)) + 1.0 for t, c in df.items()}

        # Pre-compute each document's TF-IDF vector and its L2 norm.
        self.doc_vecs: list[dict[str, float]] = []
        self.doc_norms: list[float] = []
        for toks in doc_tokens:
            tf: dict[str, int] = {}
            for t in toks:
                tf[t] = tf.get(t, 0) + 1
            vec = {t: f * self.idf.get(t, 0.0) for t, f in tf.items()}
            norm = math.sqrt(sum(v * v for v in vec.values())) or 1.0
            self.doc_vecs.append(vec)
            self.doc_norms.append(norm)

    def search(self, query: str) -> tuple[str | None, float]:
        """Return (best answer, cosine score 0–1) or (None, 0.0)."""
        qtoks = _tokens(query)
        if not qtoks or not self.doc_vecs:
            return None, 0.0

        tf: dict[str, int] = {}
        for t in qtoks:
            tf[t] = tf.get(t, 0) + 1
        qvec = {t: f * self.idf.get(t, 0.0) for t, f in tf.items()}
        qnorm = math.sqrt(sum(v * v for v in qvec.values()))
        if qnorm == 0.0:
            return None, 0.0

        n_query_terms = len(qvec)
        query_entities = {t for t in qvec if t in _ENTITY_VOCAB}
        best_i, best_score = -1, 0.0
        for i, dvec in enumerate(self.doc_vecs):
            # Dot product + how many distinct query terms this doc covers.
            dot = 0.0
            matched = 0
            for t, qv in qvec.items():
                dv = dvec.get(t)
                if dv:
                    dot += qv * dv
                    matched += 1
            if matched == 0:
                continue
            cosine = dot / (qnorm * self.doc_norms[i])
            # Reward covering more of the question: a doc that shares one
            # dominant term shouldn't beat one that matches the whole query.
            coverage = matched / n_query_terms
            score = cosine * (0.5 + 0.5 * coverage)
            # Entity agreement: boost answers about the same crop/disease the
            # question names, and dampen ones that name none of them.
            if query_entities:
                if query_entities & dvec.keys():
                    score *= 1.6
                else:
                    score *= 0.6
            if score > best_score:
                best_score, best_i = score, i

        if best_i < 0:
            return None, 0.0
        # Clamp: the entity boost can push a strong match above 1.0.
        return self.answers[best_i], min(best_score, 1.0)


_index: _Index | None = None
_loaded = False


def _get_index() -> _Index | None:
    """Build the index once, lazily. Returns None if the dataset is absent."""
    global _index, _loaded
    if _loaded:
        return _index
    _loaded = True
    if not _DATASET.exists():
        return None
    questions: list[str] = []
    answers: list[str] = []
    with open(_DATASET, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        ans_col = "answer" if "answer" in (reader.fieldnames or []) else "answers"
        for row in reader:
            q = (row.get("question") or "").strip()
            a = (row.get(ans_col) or "").strip()
            if q and a:
                questions.append(q)
                answers.append(a)
    _index = _Index(questions, answers) if questions else None
    return _index


def best_answer(question: str) -> tuple[str | None, float]:
    """Retrieve the best dataset answer for a question.

    Returns (answer, score). `score` is cosine similarity in 0–1; callers
    typically treat ≥0.30 as a confident match.
    """
    index = _get_index()
    if index is None:
        return None, 0.0
    return index.search(unframe(question))
