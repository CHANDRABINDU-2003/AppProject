"""
Curated agronomy knowledge base — the assistant's reliable safety net.

The local FLAN-T5-small model is tiny and undertrained, so on its own it often
returns empty or degenerate output (e.g. "a plant with a plant with a plant…").
When that happens — or when no model/GPT is available at all — we answer from
this hand-written knowledge base instead, so a farmer always gets practical,
correct advice for the most common questions.

Matching is deliberately simple keyword scoring (no external deps): each entry
lists trigger keywords; the entry whose keywords best overlap the question wins.
"""
from __future__ import annotations

import re

from app.services import dataset_kb
from app.services.dataset_kb import unframe as _unframe  # strip the UI's mode-framing

# Each entry: a set of trigger keywords + the answer to return.
# Ordered roughly specific → general; scoring (not order) picks the winner, but
# keeping specific topics first makes ties resolve sensibly.
_ENTRIES: list[dict] = [
    {
        "keywords": {"potato", "black", "spot", "blight", "leaf", "leaves", "dark", "lesion"},
        "answer": (
            "Black or dark spots on potato leaves are usually early blight "
            "(Alternaria) or late blight (Phytophthora). What to do:\n"
            "• Remove and destroy badly affected leaves — do not compost them.\n"
            "• Spray a protectant fungicide: mancozeb or chlorothalonil for early "
            "blight; for late blight use a copper-based fungicide or metalaxyl, "
            "repeating every 7–10 days in wet weather.\n"
            "• Avoid overhead watering and water early in the day so leaves dry fast.\n"
            "• Give plants more spacing for airflow, and rotate so potatoes/tomatoes "
            "don't grow in the same plot 2 years running.\n"
            "• Earth up tubers well so spores can't wash down to them."
        ),
    },
    {
        "keywords": {"tomato", "blight", "spot", "leaf", "leaves", "curl", "wilt", "yellow"},
        "answer": (
            "For tomato leaf problems:\n"
            "• Dark concentric spots = early blight → remove lower leaves, mulch, "
            "and spray mancozeb or chlorothalonil.\n"
            "• Greasy grey patches that spread fast in wet weather = late blight → "
            "use a copper or metalaxyl fungicide immediately and improve airflow.\n"
            "• Yellowing + curling with stunted growth can be a virus spread by "
            "whiteflies — control whiteflies and remove infected plants.\n"
            "Always water at the base, not over the leaves, and rotate crops yearly."
        ),
    },
    {
        "keywords": {"rice", "paddy", "blast", "brown", "spot", "sheath", "leaf"},
        "answer": (
            "Common rice leaf diseases:\n"
            "• Rice blast — diamond-shaped grey lesions: use a tricyclazole-based "
            "fungicide, avoid excess nitrogen, and keep steady water levels.\n"
            "• Brown spot — small brown oval spots: often a sign of poor soil/potash; "
            "balance fertilizer and treat seed before sowing.\n"
            "Use resistant varieties where available and don't over-apply nitrogen."
        ),
    },
    {
        "keywords": {"wheat", "rust", "yellow", "brown", "orange", "stripe", "leaf"},
        "answer": (
            "Orange/brown powdery pustules on wheat are rust. Manage it by:\n"
            "• Spraying a triazole fungicide (e.g. propiconazole) at first sign.\n"
            "• Growing rust-resistant varieties next season.\n"
            "• Avoiding late, heavy nitrogen which makes rust worse.\n"
            "• Removing volunteer wheat that carries the disease between seasons."
        ),
    },
    {
        "keywords": {"pest", "insect", "bug", "aphid", "caterpillar", "worm", "borer", "control"},
        "answer": (
            "Integrated pest management (IPM) keeps pests down without overusing "
            "chemicals:\n"
            "• Scout your field weekly and act early while numbers are low.\n"
            "• Encourage natural enemies (ladybirds, spiders) and use pheromone or "
            "sticky traps to monitor.\n"
            "• For soft pests like aphids, a neem-oil or insecticidal-soap spray "
            "works well.\n"
            "• Use a targeted insecticide only when pests cross the economic "
            "threshold, and rotate chemical groups so pests don't build resistance."
        ),
    },
    {
        "keywords": {"fertilizer", "fertiliser", "npk", "nutrient", "nitrogen", "phosphorus",
                     "potash", "urea", "feed", "dose"},
        "answer": (
            "Fertilize based on what your soil and crop actually need:\n"
            "• Start with a soil test for N, P, K and pH — guessing wastes money.\n"
            "• Nitrogen drives leafy growth, phosphorus roots/flowering, potassium "
            "overall vigour and disease resistance.\n"
            "• Split nitrogen into 2–3 doses through the season instead of all at "
            "once, to cut leaching.\n"
            "• Add compost or manure to build organic matter.\n"
            "Tip: open the Fertilizer tab in the app for a recommendation tailored "
            "to your soil and crop."
        ),
    },
    {
        "keywords": {"soil", "ph", "acidic", "alkaline", "health", "organic", "compost", "fertility"},
        "answer": (
            "Healthy soil is the foundation of a good crop:\n"
            "• Test pH — most crops like 6.0–7.0. Add lime to raise a low (acidic) "
            "pH, or elemental sulphur/organic matter to lower a high one.\n"
            "• Add compost or well-rotted manure every season to feed soil life.\n"
            "• Keep the soil covered with mulch or cover crops to stop erosion and "
            "hold moisture.\n"
            "• Avoid working soil when it's very wet, which compacts it."
        ),
    },
    {
        "keywords": {"rice", "paddy", "water", "irrigation", "watering", "much", "need"},
        "answer": (
            "Rice is a thirsty crop — it needs far more water than most:\n"
            "• Keep 5–10 cm of standing water in the paddy through most of the "
            "growing season; never let transplanted fields dry out for long.\n"
            "• A rice crop typically needs ~1,200–1,500 mm of water over the season.\n"
            "• You can drain the field briefly at tillering and again ~10 days "
            "before harvest, but keep it flooded during flowering — water stress "
            "then sharply cuts yield.\n"
            "• On sandy soil that drains fast, irrigate more often to hold the "
            "water level."
        ),
    },
    {
        "keywords": {"water", "irrigation", "watering", "drought", "dry", "moisture"},
        "answer": (
            "Water wisely to save the crop and the bill:\n"
            "• Water deeply but less often so roots grow down — light daily sprinkles "
            "keep roots shallow and weak.\n"
            "• Water early morning or evening to cut evaporation.\n"
            "• Drip irrigation delivers water straight to the roots and keeps leaves "
            "dry (which also reduces disease).\n"
            "• Mulch around plants to hold soil moisture during dry spells."
        ),
    },
    {
        "keywords": {"treat", "disease", "diseased", "sick", "infection", "cure",
                     "manage", "fungus", "fungal", "spreading"},
        "answer": (
            "General steps to treat a crop disease:\n"
            "• Identify it first — scan a leaf in the Disease Detection tab so you "
            "treat the right problem.\n"
            "• Remove and destroy badly affected leaves/plants (don't compost them) "
            "to stop the spread.\n"
            "• For fungal diseases (spots, blights, mildews) apply a protectant "
            "fungicide such as mancozeb, chlorothalonil or a copper spray, repeating "
            "every 7–10 days in wet weather.\n"
            "• Improve airflow with wider spacing, water at the base in the morning, "
            "and rotate crops so the same disease can't build up in the soil.\n"
            "Tell me the crop and exact symptom for a more specific treatment."
        ),
    },
    {
        "keywords": {"demand", "market", "price", "prices", "sell", "selling",
                     "profit", "trend", "trends", "buyers", "high"},
        "answer": (
            "Market demand and prices shift by season and region, so check live "
            "signals rather than a fixed list:\n"
            "• Staples like rice, wheat and maize have steady, reliable demand; "
            "vegetables (tomato, cabbage, onion) often fetch higher prices but swing "
            "more.\n"
            "• Watch what's scarce locally — a crop few others are growing this "
            "season usually sells best.\n"
            "• Use the Analytics and Marketplace tabs to see recent orders and "
            "prices in your region before deciding what to stock or plant."
        ),
    },
    {
        "keywords": {"rotation", "rotate", "crop", "season", "plan", "sequence"},
        "answer": (
            "Crop rotation breaks pest and disease cycles and keeps soil fertile:\n"
            "• Don't grow the same crop family in the same plot two seasons running.\n"
            "• Follow a heavy feeder (maize, cabbage) with a legume (beans, lentils) "
            "that puts nitrogen back into the soil.\n"
            "• Alternate deep-rooted and shallow-rooted crops to use the whole soil "
            "profile.\n"
            "A simple 3–4 year rotation noticeably cuts disease pressure."
        ),
    },
    {
        "keywords": {"weather", "rain", "storm", "flood", "heat", "frost", "wind", "climate"},
        "answer": (
            "Plan around the weather to protect your harvest:\n"
            "• Heavy rain/flood: improve field drainage and avoid spraying right "
            "before rain washes it off.\n"
            "• Heatwave: irrigate in the cool hours and mulch to keep roots cool.\n"
            "• Frost: cover seedlings overnight and irrigate lightly before a frost, "
            "as moist soil holds heat.\n"
            "Check the disaster-alert card on your dashboard for warnings near you."
        ),
    },
    {
        "keywords": {"weed", "weeds", "grass", "unwanted"},
        "answer": (
            "Keep weeds from stealing water and nutrients:\n"
            "• Mulch heavily to block weed seedlings from getting light.\n"
            "• Hoe or hand-weed while weeds are small, before they seed.\n"
            "• Use a pre-emergence herbicide only if needed, and follow the label "
            "rate exactly.\n"
            "Never let weeds set seed — 'one year's seeding is seven years' weeding.'"
        ),
    },
]

# A safe, useful default when nothing matches well.
_DEFAULT = (
    "Here's some general guidance: keep an eye on your crop weekly, remove any "
    "diseased leaves early, water at the base in the cool hours, and feed the soil "
    "with compost plus a balanced NPK based on a soil test. If you can tell me the "
    "crop and the exact symptom (e.g. 'yellow spots on potato leaves'), I can give "
    "you a more specific solution. You can also use the Disease tab to scan a leaf "
    "photo or the Fertilizer tab for a tailored recommendation."
)

_WORD_RE = re.compile(r"[a-z]+")


def _tokens(text: str) -> set[str]:
    return set(_WORD_RE.findall(text.lower()))


def curated_answer(question: str) -> str | None:
    """Return a hand-written answer ONLY when it's a confident topic match.

    Requires at least two keyword hits, so a single weak overlap (e.g. just
    "leaf") doesn't trigger. Returns None when no entry is trusted, letting the
    caller try the model or retrieval. These curated answers are authoritative
    for the most common questions, so callers check this first.
    """
    q = _tokens(_unframe(question))
    if not q:
        return None

    best_score = 0
    best_answer: str | None = None
    for entry in _ENTRIES:
        score = len(q & entry["keywords"])
        if score > best_score:
            best_score = score
            best_answer = entry["answer"]

    return best_answer if best_score >= 2 else None


def answer(question: str) -> str:
    """Return the most reliable grounded answer for a free-text question.

    Order of trust:
      1. A curated hand-written entry (best for the most common topics).
      2. The retrieval knowledge base — the closest of ~2,200 real Q&A pairs,
         when it's a confident match. This covers the long tail and is why the
         assistant can answer real questions even when the model loops.
      3. A safe generic prompt asking for crop + symptom.
    """
    curated = curated_answer(question)
    if curated is not None:
        return curated

    # Long tail: retrieve the closest real answer from the training corpus.
    retrieved, score = dataset_kb.best_answer(question)
    if retrieved and score >= 0.30:
        return retrieved

    return _DEFAULT
