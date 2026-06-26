"""
Pydantic schemas = the JSON shapes the API accepts (requests) and returns (responses).
`from_attributes=True` lets us return SQLAlchemy objects directly.
"""
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr

from app.models import (
    AppointmentStatus, BroadcastCategory, OrderStatus, Role, Severity,
)

ORM = ConfigDict(from_attributes=True)


# ─────────── Auth ───────────
class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    role: Role
    region_id: int | None = None


class UserOut(BaseModel):
    model_config = ORM
    id: int
    name: str
    email: EmailStr
    role: Role
    region_id: int | None = None
    created_at: datetime


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


# ─────────── Farmer profile + crop history ───────────
class FarmerProfileIn(BaseModel):
    farm_size: float | None = None
    soil_type: str | None = None
    main_crop: str | None = None


class FarmerProfileOut(FarmerProfileIn):
    model_config = ORM
    id: int
    user_id: int


class CropHistoryIn(BaseModel):
    crop_type: str
    season: str
    yield_amount: float | None = None
    fertilizer_used: str | None = None
    quantity: float | None = None
    price: float | None = None
    crop_date: str | None = None        # ISO date string yyyy-mm-dd


class CropHistoryOut(CropHistoryIn):
    model_config = ORM
    id: int
    farmer_id: int
    created_at: datetime


# ─────────── ML records ───────────
class FertilizerPredictionOut(BaseModel):
    model_config = ORM
    id: int
    predicted_fertilizer: str | None
    confidence: float | None
    input_data: dict | None
    created_at: datetime


class DiseaseResultOut(BaseModel):
    model_config = ORM
    id: int
    image_url: str | None
    disease_name: str | None
    confidence: float | None
    created_at: datetime


# ─────────── Community ───────────
class PostIn(BaseModel):
    text: str
    image_url: str | None = None


class CommentIn(BaseModel):
    comment: str


class CommentOut(CommentIn):
    model_config = ORM
    id: int
    post_id: int
    user_id: int
    created_at: datetime


class PostOut(BaseModel):
    model_config = ORM
    id: int
    user_id: int
    text: str | None
    image_url: str | None
    likes: int
    created_at: datetime
    comments: list[CommentOut] = []


# ─────────── Seller / commerce ───────────
class ProductIn(BaseModel):
    name: str
    type: str
    price: float
    stock: int
    region_id: int | None = None


class ProductOut(ProductIn):
    model_config = ORM
    id: int
    seller_id: int


class OrderIn(BaseModel):
    product_id: int
    quantity: int = 1


class OrderOut(BaseModel):
    model_config = ORM
    id: int
    farmer_id: int
    product_id: int
    quantity: int
    status: OrderStatus
    created_at: datetime


class OrderStatusUpdate(BaseModel):
    status: OrderStatus


class SellerOrderOut(BaseModel):
    """An incoming order enriched for the seller: who ordered, what, and where."""
    id: int
    product_id: int
    product_name: str | None
    quantity: int
    status: OrderStatus
    farmer_name: str | None
    region_name: str | None
    created_at: datetime


# ─────────── Consultations / appointments (consult the analyst) ───────────
class AppointmentIn(BaseModel):
    scheduled_date: str         # ISO date string yyyy-mm-dd
    topic: str | None = None    # the problem the farmer describes


class AppointmentOut(BaseModel):
    model_config = ORM
    id: int
    farmer_id: int | None = None
    expert_id: int
    expert_name: str
    scheduled_date: str
    scheduled_time: str | None
    topic: str | None
    status: AppointmentStatus
    created_at: datetime


class AppointmentStatusUpdate(BaseModel):
    """The analyst accepts / rejects / completes a consultation request."""
    status: AppointmentStatus


class AppointmentAdminOut(AppointmentOut):
    """Appointment row enriched for the analyst's queue: who requested it
    (farmer or seller) and their role."""
    farmer_name: str | None = None
    requester_name: str | None = None
    requester_role: Role | None = None


# ─────────── Reference ───────────
class RegionOut(BaseModel):
    model_config = ORM
    id: int
    region_name: str


# ─────────── Farm analytics ───────────
class RevenuePoint(BaseModel):
    month: str           # yyyy-mm
    revenue: float


class FarmAnalyticsOut(BaseModel):
    total_crops: int
    healthy_crops: int
    diseased_crops: int
    marketplace_orders: int
    revenue: float
    revenue_series: list[RevenuePoint] = []


# ─────────── Regional farming tips ───────────
class FarmingTip(BaseModel):
    title: str
    body: str


class RegionalTipsOut(BaseModel):
    region_id: int | None = None
    region_name: str | None = None
    tips: list[FarmingTip] = []


# ─────────── Crop calendar ───────────
class CropStageOut(BaseModel):
    key: str
    label: str
    day_offset: int
    date: str
    note: str | None = None


class CropCalendarOut(BaseModel):
    crop: str
    sowing_date: str
    stages: list[CropStageOut]


# ─────────── Region-based discovery (Seller ↔ Farmer mutual visibility) ───────────
class NearbyUserOut(BaseModel):
    """A nearby seller (shown to farmers) or farmer (shown to sellers), by region."""
    model_config = ORM
    id: int
    name: str
    email: EmailStr
    role: Role
    region_id: int | None = None


# ─────────── Disaster broadcasts ───────────
class BroadcastIn(BaseModel):
    title: str
    category: BroadcastCategory
    description: str | None = None
    region_id: int | None = None        # null = all regions
    severity: Severity = Severity.medium
    event_date: str | None = None       # ISO yyyy-mm-dd


class BroadcastOut(BaseModel):
    model_config = ORM
    id: int
    title: str
    category: BroadcastCategory
    description: str | None
    region_id: int | None
    region_name: str | None = None
    severity: Severity
    event_date: str | None
    created_by_analyst: int
    created_at: datetime


# ─────────── Regional analytics (analyst dashboard) ───────────
class RegionStat(BaseModel):
    """Aggregated farming metrics for a single region."""
    region_id: int
    region_name: str
    farmers: int
    total_yield: float
    revenue: float
    disease_count: int
    fertilizer_usage: int


class RegionSuperlative(BaseModel):
    """A "winner" region for one metric (e.g. highest yield)."""
    region_id: int | None = None
    region_name: str | None = None
    value: float = 0


class RegionalAnalyticsOut(BaseModel):
    regions: list[RegionStat] = []
    best_performing: RegionSuperlative          # by revenue
    worst_performing: RegionSuperlative         # by revenue (lowest, among active)
    highest_yield: RegionSuperlative
    highest_disease: RegionSuperlative
    highest_fertilizer: RegionSuperlative


# ─────────── Community monitoring (analyst, read-only) ───────────
class TrendingProblem(BaseModel):
    keyword: str
    count: int


class MonitoredPost(BaseModel):
    model_config = ORM
    id: int
    user_id: int
    author_name: str | None = None
    text: str | None
    likes: int
    comment_count: int = 0
    flagged: bool = False               # heuristic: looks like an urgent problem
    created_at: datetime


class CommunityMonitorOut(BaseModel):
    total_posts: int
    total_comments: int
    flagged_count: int
    trending: list[TrendingProblem] = []
    posts: list[MonitoredPost] = []
    flagged_posts: list[MonitoredPost] = []
