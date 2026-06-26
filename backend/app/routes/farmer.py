"""
Farmer routes (role = farmer).

Farmer flow (from the report):
  Login -> Dashboard -> AI Request -> FastAPI -> ML Model -> PostgreSQL -> Response

Covers: profile, crop history, disease detection, fertilizer recommendation.
"""
import csv
from datetime import date
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import require_role
from app.models import (
    CropHistory, DiseaseResult, Farmer, FertilizerPrediction, Order, Region,
    Role, User,
)
from app.schemas import (
    CropCalendarOut, CropHistoryIn, CropHistoryOut, DiseaseResultOut,
    FarmAnalyticsOut, FarmerProfileIn, FarmerProfileOut, FertilizerPredictionOut,
    NearbyUserOut, RegionalTipsOut,
)
from app.services import ai_client, crop_calendar
from app.services.regional_tips import tips_for_region

router = APIRouter(prefix="/farmer", tags=["farmer"])

# Every endpoint here requires a logged-in farmer.
farmer_only = require_role(Role.farmer)

# The crop-history dataset that farmer entries are appended to (so each crop a
# farmer logs grows the training dataset). Lives in database/seed/data/.
_CROP_DATASET = (
    Path(__file__).resolve().parents[3] / "database" / "seed" / "data" / "crop_history.csv"
)
_CROP_DATASET_COLUMNS = [
    "email", "crop_type", "season", "yield_amount", "fertilizer_used",
    "quantity", "price", "crop_date",
]


def _append_to_dataset(email: str, payload: "CropHistoryIn") -> None:
    """Append one logged crop to datasets/crop_history.csv.

    Best-effort: never let a dataset write break the API response. Writes a
    header first if the file is new/empty.
    """
    try:
        new_file = not _CROP_DATASET.exists() or _CROP_DATASET.stat().st_size == 0
        with open(_CROP_DATASET, "a", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=_CROP_DATASET_COLUMNS)
            if new_file:
                writer.writeheader()
            writer.writerow({
                "email": email,
                "crop_type": payload.crop_type,
                "season": payload.season,
                "yield_amount": payload.yield_amount if payload.yield_amount is not None else "",
                "fertilizer_used": payload.fertilizer_used or "",
                "quantity": payload.quantity if payload.quantity is not None else "",
                "price": payload.price if payload.price is not None else "",
                "crop_date": payload.crop_date or "",
            })
    except OSError:
        pass  # dataset is a convenience; the DB row is the source of truth


def _profile(db: Session, user: User) -> Farmer:
    prof = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    if not prof:
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    return prof


# ─────────── Profile ───────────
@router.get("/profile", response_model=FarmerProfileOut)
def get_profile(db: Session = Depends(get_db), user: User = Depends(farmer_only)):
    return _profile(db, user)


@router.put("/profile", response_model=FarmerProfileOut)
def update_profile(
    payload: FarmerProfileIn,
    db: Session = Depends(get_db),
    user: User = Depends(farmer_only),
):
    prof = _profile(db, user)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(prof, field, value)
    db.commit()
    db.refresh(prof)
    return prof


# ─────────── Crop history ───────────
@router.post("/crop-history", response_model=CropHistoryOut, status_code=201)
def add_crop_history(
    payload: CropHistoryIn,
    db: Session = Depends(get_db),
    user: User = Depends(farmer_only),
):
    prof = _profile(db, user)
    row = CropHistory(farmer_id=prof.id, **payload.model_dump())
    db.add(row)
    db.commit()
    db.refresh(row)
    # Grow the farmer's dataset with this entry.
    _append_to_dataset(user.email, payload)
    return row


@router.get("/crop-history", response_model=list[CropHistoryOut])
def list_crop_history(db: Session = Depends(get_db), user: User = Depends(farmer_only)):
    prof = _profile(db, user)
    return (
        db.query(CropHistory)
        .filter(CropHistory.farmer_id == prof.id)
        .order_by(CropHistory.created_at.desc())
        .all()
    )


# ─────────── Disease detection (image -> AI service -> DB) ───────────
@router.post("/disease/detect")
async def detect_disease(
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(farmer_only),
):
    prof = _profile(db, user)
    image_bytes = await image.read()
    result = await ai_client.predict_disease(image_bytes, image.filename or "leaf.jpg")

    row = DiseaseResult(
        farmer_id=prof.id,
        image_url=image.filename,           # TODO: upload to storage, save real URL
        disease_name=result.get("disease"),
        confidence=result.get("confidence", 0.0),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    # Return the saved row plus the model's treatment advice (not persisted) so
    # the app can show a full diagnosis: name + confidence + what to do next.
    return {
        "id": row.id,
        "disease_name": row.disease_name,
        "confidence": row.confidence,
        "recommendation": result.get("recommendation", ""),
        "created_at": row.created_at,
    }


@router.get("/disease/history", response_model=list[DiseaseResultOut])
def disease_history(db: Session = Depends(get_db), user: User = Depends(farmer_only)):
    prof = _profile(db, user)
    return (
        db.query(DiseaseResult)
        .filter(DiseaseResult.farmer_id == prof.id)
        .order_by(DiseaseResult.created_at.desc())
        .all()
    )


# ─────────── Fertilizer recommendation (features -> AI service -> DB) ───────────
@router.post("/fertilizer/recommend", response_model=FertilizerPredictionOut)
async def recommend_fertilizer(
    features: dict,
    db: Session = Depends(get_db),
    user: User = Depends(farmer_only),
):
    """`features` = soil + crop dict matching fertilizer_recommendation.csv columns."""
    prof = _profile(db, user)
    result = await ai_client.predict_fertilizer(features)

    row = FertilizerPrediction(
        farmer_id=prof.id,
        input_data=features,
        predicted_fertilizer=result.get("predicted_fertilizer"),
        confidence=result.get("confidence", 0.0),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.get("/fertilizer/history", response_model=list[FertilizerPredictionOut])
def fertilizer_history(db: Session = Depends(get_db), user: User = Depends(farmer_only)):
    prof = _profile(db, user)
    return (
        db.query(FertilizerPrediction)
        .filter(FertilizerPrediction.farmer_id == prof.id)
        .order_by(FertilizerPrediction.created_at.desc())
        .all()
    )


# ─────────── Farm analytics (aggregated dashboard numbers) ───────────
@router.get("/analytics", response_model=FarmAnalyticsOut)
def farm_analytics(db: Session = Depends(get_db), user: User = Depends(farmer_only)):
    """Totals + monthly revenue series for the farmer's analytics dashboard."""
    prof = _profile(db, user)

    crops = db.query(CropHistory).filter(CropHistory.farmer_id == prof.id).all()
    total_crops = len(crops)
    diseased = (
        db.query(DiseaseResult).filter(DiseaseResult.farmer_id == prof.id).count()
    )
    orders = db.query(Order).filter(Order.farmer_id == prof.id).count()

    # Revenue = price × quantity recorded per logged crop. Also bucket it by the
    # crop's month so the dashboard can draw a revenue-over-time chart.
    revenue = 0.0
    by_month: dict[str, float] = {}
    for c in crops:
        amount = (c.price or 0) * (c.quantity or 0)
        revenue += amount
        if amount and c.crop_date:
            month = c.crop_date[:7]          # yyyy-mm from an ISO date string
            by_month[month] = by_month.get(month, 0.0) + amount

    revenue_series = [
        {"month": m, "revenue": round(v, 2)} for m, v in sorted(by_month.items())
    ]

    return {
        "total_crops": total_crops,
        "healthy_crops": max(total_crops - diseased, 0),
        "diseased_crops": diseased,
        "marketplace_orders": orders,
        "revenue": round(revenue, 2),
        "revenue_series": revenue_series,
    }


# ─────────── Nearby sellers (region-based visibility) ───────────
@router.get("/nearby-sellers", response_model=list[NearbyUserOut])
def nearby_sellers(
    region_id: int | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(farmer_only),
):
    """Sellers in the selected region (defaults to the farmer's own region).

    Powers the farmer dashboard's "nearby sellers" view — the mirror of the
    seller's "nearby farmers" list.
    """
    target_region = region_id if region_id is not None else user.region_id
    q = db.query(User).filter(User.role == Role.seller, User.is_active == True)  # noqa: E712
    if target_region is not None:
        q = q.filter(User.region_id == target_region)
    return q.order_by(User.name).all()


# ─────────── Regional farming tips (region-specific advice cards) ───────────
@router.get("/regional-tips", response_model=RegionalTipsOut)
def regional_tips(db: Session = Depends(get_db), user: User = Depends(farmer_only)):
    """Curated farming tips for the farmer's own region (shown on Analytics)."""
    region = (
        db.query(Region).filter(Region.id == user.region_id).first()
        if user.region_id is not None
        else None
    )
    region_name = region.region_name if region else None
    return {
        "region_id": user.region_id,
        "region_name": region_name,
        "tips": tips_for_region(region_name),
    }


# ─────────── Crop calendar (stage plan from crop + sowing date) ───────────
@router.get("/crop-calendar", response_model=CropCalendarOut)
def crop_calendar_plan(
    crop: str = Query(..., description="Crop name, e.g. rice, wheat, potato"),
    sowing_date: str | None = Query(
        None, description="ISO sowing date yyyy-mm-dd (defaults to today)"
    ),
    user: User = Depends(farmer_only),
):
    """Compute the key farming stages (sowing → harvest) with dates."""
    try:
        sowing = date.fromisoformat(sowing_date) if sowing_date else date.today()
    except ValueError:
        raise HTTPException(status_code=400, detail="sowing_date must be yyyy-mm-dd")
    return crop_calendar.build_calendar(crop, sowing)
