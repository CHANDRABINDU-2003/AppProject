"""
Analyst oversight routes (role = analyst).

Powers the analyst dashboard's two read-only analytics surfaces:

  GET /analyst/regional-analytics  — per-region farming metrics + superlatives
                                     (best/worst region, highest yield/disease/
                                      fertilizer) for the bar/line/pie charts.
  GET /analyst/community-monitor    — a read-only view of the community feed:
                                     trending problems, flagged posts, discussion
                                     volume. The analyst never edits posts.

These aggregate across every farmer/region, so they live behind the single
analyst account rather than being computed client-side.
"""
import re
from collections import Counter

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import require_role
from app.models import (
    Comment, CropHistory, DiseaseResult, Farmer, Post, Region, Role, User,
)
from app.schemas import (
    CommunityMonitorOut, MonitoredPost, RegionalAnalyticsOut, RegionStat,
    RegionSuperlative, TrendingProblem,
)

router = APIRouter(prefix="/analyst", tags=["analyst"])
analyst_only = require_role(Role.analyst)


# Words that suggest a post is an urgent problem worth the analyst's attention.
_PROBLEM_WORDS = {
    "disease", "pest", "infestation", "dying", "dead", "rot", "rotting", "blight",
    "fungus", "flood", "flooded", "drought", "attack", "infected", "wilting",
    "yellowing", "damage", "damaged", "loss", "urgent", "help", "emergency",
    "outbreak", "insect", "worm", "locust", "failure", "spoiled",
}
# Common, low-signal words to ignore when ranking "trending problems".
_STOPWORDS = {
    "the", "and", "for", "are", "but", "not", "you", "all", "any", "can", "had",
    "her", "was", "one", "our", "out", "has", "him", "his", "how", "man", "new",
    "now", "old", "see", "two", "way", "who", "boy", "did", "its", "let", "put",
    "say", "she", "too", "use", "with", "this", "that", "have", "from", "they",
    "what", "your", "when", "will", "would", "there", "their", "about", "which",
    "crop", "crops", "farm", "farmer", "field", "please", "some", "very", "been",
    "more", "than", "then", "them", "into", "over", "just", "like", "also",
}


@router.get("/regional-analytics", response_model=RegionalAnalyticsOut)
def regional_analytics(
    db: Session = Depends(get_db),
    user: User = Depends(analyst_only),
):
    regions = db.query(Region).order_by(Region.id).all()

    # Map each farmer to a region via their user account.
    farmer_region: dict[int, int | None] = {}
    farmer_count: dict[int, int] = {r.id: 0 for r in regions}
    for f in db.query(Farmer).join(User, Farmer.user_id == User.id).all():
        farmer_region[f.id] = f.user.region_id
        if f.user.region_id in farmer_count:
            farmer_count[f.user.region_id] += 1

    yield_by: dict[int, float] = {r.id: 0.0 for r in regions}
    revenue_by: dict[int, float] = {r.id: 0.0 for r in regions}
    fert_by: dict[int, int] = {r.id: 0 for r in regions}
    for c in db.query(CropHistory).all():
        rid = farmer_region.get(c.farmer_id)
        if rid not in yield_by:
            continue
        yield_by[rid] += c.yield_amount or 0
        revenue_by[rid] += (c.price or 0) * (c.quantity or 0)
        if c.fertilizer_used:
            fert_by[rid] += 1

    disease_by: dict[int, int] = {r.id: 0 for r in regions}
    for d in db.query(DiseaseResult).all():
        rid = farmer_region.get(d.farmer_id)
        if rid in disease_by:
            disease_by[rid] += 1

    stats = [
        RegionStat(
            region_id=r.id,
            region_name=r.region_name,
            farmers=farmer_count.get(r.id, 0),
            total_yield=round(yield_by.get(r.id, 0.0), 2),
            revenue=round(revenue_by.get(r.id, 0.0), 2),
            disease_count=disease_by.get(r.id, 0),
            fertilizer_usage=fert_by.get(r.id, 0),
        )
        for r in regions
    ]

    def _top(metric, *, lowest=False, only_active=False) -> RegionSuperlative:
        pool = [s for s in stats if (not only_active or metric(s) > 0)]
        if not pool:
            return RegionSuperlative()
        chosen = (min if lowest else max)(pool, key=metric)
        return RegionSuperlative(
            region_id=chosen.region_id,
            region_name=chosen.region_name,
            value=round(float(metric(chosen)), 2),
        )

    return RegionalAnalyticsOut(
        regions=stats,
        best_performing=_top(lambda s: s.revenue),
        worst_performing=_top(lambda s: s.revenue, lowest=True, only_active=True),
        highest_yield=_top(lambda s: s.total_yield),
        highest_disease=_top(lambda s: s.disease_count),
        highest_fertilizer=_top(lambda s: s.fertilizer_usage),
    )


@router.get("/community-monitor", response_model=CommunityMonitorOut)
def community_monitor(
    db: Session = Depends(get_db),
    user: User = Depends(analyst_only),
):
    posts = db.query(Post).order_by(Post.created_at.desc()).all()
    authors = {u.id: u.name for u in db.query(User).all()}

    comment_counts: dict[int, int] = {}
    total_comments = 0
    for c in db.query(Comment).all():
        comment_counts[c.post_id] = comment_counts.get(c.post_id, 0) + 1
        total_comments += 1

    word_counter: Counter[str] = Counter()
    monitored: list[MonitoredPost] = []
    flagged: list[MonitoredPost] = []
    for p in posts:
        text = p.text or ""
        words = {w for w in re.findall(r"[a-zA-Z]{3,}", text.lower())}
        is_flagged = bool(words & _PROBLEM_WORDS)
        for w in words:
            if w in _PROBLEM_WORDS:
                word_counter[w] += 1
        mp = MonitoredPost(
            id=p.id,
            user_id=p.user_id,
            author_name=authors.get(p.user_id),
            text=p.text,
            likes=p.likes or 0,
            comment_count=comment_counts.get(p.id, 0),
            flagged=is_flagged,
            created_at=p.created_at,
        )
        monitored.append(mp)
        if is_flagged:
            flagged.append(mp)

    trending = [
        TrendingProblem(keyword=w, count=n) for w, n in word_counter.most_common(8)
    ]

    return CommunityMonitorOut(
        total_posts=len(posts),
        total_comments=total_comments,
        flagged_count=len(flagged),
        trending=trending,
        posts=monitored,
        flagged_posts=flagged,
    )
