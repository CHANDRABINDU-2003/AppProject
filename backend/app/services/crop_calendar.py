"""
Crop calendar generator.

Given a crop and a sowing date, returns the key farming stages (sowing,
fertilizer, irrigation, harvest, …) with a concrete date for each — computed
from per-crop "days after sowing" templates. Stateless and key-less, so it
works out of the box and gives the farmer a simple plan to follow.
"""
from __future__ import annotations

from datetime import date, timedelta

# Each stage = (key, label, days-after-sowing, short note).
# Tuned to be realistic-ish for smallholder planning, not agronomically exact.
_TEMPLATES: dict[str, list[tuple[str, str, int, str]]] = {
    "rice": [
        ("sowing", "Sowing / transplanting", 0, "Prepare the seedbed and transplant seedlings."),
        ("fertilizer", "Basal fertilizer", 14, "Apply urea / NPK as the first top dressing."),
        ("irrigation", "Irrigation", 21, "Keep 3–5 cm standing water during tillering."),
        ("fertilizer_2", "Second fertilizer", 45, "Top-dress nitrogen at panicle initiation."),
        ("harvest", "Harvest", 120, "Harvest when 80% of grains turn golden."),
    ],
    "wheat": [
        ("sowing", "Sowing", 0, "Sow into well-prepared, moist soil."),
        ("fertilizer", "Basal fertilizer", 21, "Apply nitrogen at crown-root initiation."),
        ("irrigation", "Irrigation", 30, "Irrigate at the tillering stage."),
        ("fertilizer_2", "Second fertilizer", 50, "Second nitrogen dose before flowering."),
        ("harvest", "Harvest", 130, "Harvest when grain is hard and golden."),
    ],
    "maize": [
        ("sowing", "Sowing", 0, "Sow at 4–5 cm depth in warm soil."),
        ("fertilizer", "Basal fertilizer", 18, "Apply nitrogen at the knee-high stage."),
        ("irrigation", "Irrigation", 28, "Irrigate at tasseling — the most sensitive stage."),
        ("harvest", "Harvest", 100, "Harvest when husks dry and kernels dent."),
    ],
    "potato": [
        ("sowing", "Planting", 0, "Plant healthy, sprouted seed tubers."),
        ("fertilizer", "Fertilizer", 20, "Apply NPK and earth up the ridges."),
        ("irrigation", "Irrigation", 30, "Keep soil moist during tuber bulking."),
        ("harvest", "Harvest", 95, "Harvest once the haulms (tops) die down."),
    ],
    "tomato": [
        ("sowing", "Transplanting", 0, "Transplant 4–5 week old seedlings."),
        ("fertilizer", "Fertilizer", 15, "Side-dress nitrogen after establishment."),
        ("irrigation", "Irrigation", 25, "Irrigate regularly; avoid wetting the leaves."),
        ("harvest", "Harvest", 75, "Pick fruit as it turns from green to red."),
    ],
    "jute": [
        ("sowing", "Sowing", 0, "Broadcast or line-sow seed in fine tilth."),
        ("fertilizer", "Fertilizer", 25, "Top-dress nitrogen after thinning."),
        ("irrigation", "Irrigation", 35, "Irrigate in dry spells during fast growth."),
        ("harvest", "Harvest", 120, "Harvest at small-pod stage for best fibre."),
    ],
}

# Used when the crop isn't in the table — a sensible generic plan.
_DEFAULT = [
    ("sowing", "Sowing", 0, "Sow into well-prepared, moist soil."),
    ("fertilizer", "Fertilizer", 20, "Apply a balanced fertilizer dose."),
    ("irrigation", "Irrigation", 30, "Irrigate during the main growth phase."),
    ("harvest", "Harvest", 100, "Harvest at crop maturity."),
]


def supported_crops() -> list[str]:
    return sorted(_TEMPLATES.keys())


def build_calendar(crop: str, sowing: date) -> dict:
    """Return the calendar (crop, sowing date, list of dated stages)."""
    template = _TEMPLATES.get((crop or "").strip().lower(), _DEFAULT)
    stages = [
        {
            "key": key,
            "label": label,
            "day_offset": offset,
            "date": (sowing + timedelta(days=offset)).isoformat(),
            "note": note,
        }
        for key, label, offset, note in template
    ]
    return {
        "crop": crop,
        "sowing_date": sowing.isoformat(),
        "stages": stages,
    }
