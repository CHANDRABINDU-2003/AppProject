"""
Database schema (PostgreSQL via SQLAlchemy ORM).

This single file is the core system design referenced in the project report.
Every class = one table. Relationships let us navigate, e.g. `farmer.user.name`.

Roles:
  farmer  — grows crops, uses the AI tools, buys from sellers.
  seller  — sells products to farmers (the marketplace supply side).
  analyst — a single, system-wide oversight account. NOT registerable; only the
            one seeded analyst credential may log in (see app/routes/auth.py).
"""
import enum
from datetime import datetime

from sqlalchemy import (
    Boolean, Column, DateTime, Enum, Float, ForeignKey, Integer, String, Text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship

from app.database import Base


# ─────────────────────────── Enums ───────────────────────────
class Role(str, enum.Enum):
    farmer = "farmer"
    seller = "seller"
    analyst = "analyst"           # single oversight account, not registerable


class OrderStatus(str, enum.Enum):
    pending = "pending"
    confirmed = "confirmed"
    shipped = "shipped"
    delivered = "delivered"
    cancelled = "cancelled"


class AppointmentStatus(str, enum.Enum):
    pending = "pending"
    confirmed = "confirmed"
    completed = "completed"
    cancelled = "cancelled"


class Severity(str, enum.Enum):
    """How urgent a disaster broadcast is — drives the colour/priority in the UI."""
    low = "low"
    medium = "medium"
    high = "high"
    critical = "critical"


class BroadcastCategory(str, enum.Enum):
    """The kind of disaster an analyst can broadcast to a region."""
    flood = "flood"
    cyclone = "cyclone"
    heavy_rain = "heavy_rain"
    pest_outbreak = "pest_outbreak"
    disease_outbreak = "disease_outbreak"


# ─────────────────────────── Reference ───────────────────────────
class Region(Base):
    """8 regions (e.g. the 8 divisions). Used to match nearby farmers and sellers."""
    __tablename__ = "regions"
    id = Column(Integer, primary_key=True)
    region_name = Column(String(100), unique=True, nullable=False)

    users = relationship("User", back_populates="region")
    broadcasts = relationship("Broadcast", back_populates="region")


# ─────────────────────────── Knowledge masters (RAG context) ───────────────────────────
# These curated reference tables are searched BEFORE the FLAN-T5 chatbot runs, so
# the model answers with grounded facts (a small Retrieval-Augmented Generation
# step) instead of hallucinating. See app/services/knowledge.py.
class CropMaster(Base):
    """Reference facts about a crop (season, water needs)."""
    __tablename__ = "crop_master"
    id = Column(Integer, primary_key=True)
    name = Column(String(100), unique=True, nullable=False, index=True)
    description = Column(Text)
    season = Column(String(100))
    water_requirement = Column(String(100))


class DiseaseMaster(Base):
    """Reference facts about a crop disease (symptoms + treatment)."""
    __tablename__ = "disease_master"
    id = Column(Integer, primary_key=True)
    name = Column(String(200), unique=True, nullable=False, index=True)
    symptoms = Column(Text)
    solution = Column(Text)


class FertilizerMaster(Base):
    """Reference facts about a fertilizer (what it is used for)."""
    __tablename__ = "fertilizer_master"
    id = Column(Integer, primary_key=True)
    name = Column(String(100), unique=True, nullable=False, index=True)
    used_for = Column(Text)


# ─────────────────────────── Users (all roles) ───────────────────────────
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    password_hash = Column(Text, nullable=False)
    role = Column(Enum(Role), nullable=False, index=True)
    region_id = Column(Integer, ForeignKey("regions.id"), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    region = relationship("Region", back_populates="users")
    farmer = relationship("Farmer", back_populates="user", uselist=False)
    posts = relationship("Post", back_populates="author")
    comments = relationship("Comment", back_populates="author")
    products = relationship("Product", back_populates="seller")     # sellers only


# ─────────────────────────── Farmer domain ───────────────────────────
class Farmer(Base):
    __tablename__ = "farmers"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    farm_size = Column(Float)               # in acres/hectares
    soil_type = Column(String(50))
    main_crop = Column(String(50))

    user = relationship("User", back_populates="farmer")
    crop_history = relationship("CropHistory", back_populates="farmer")
    fertilizer_predictions = relationship("FertilizerPrediction", back_populates="farmer")
    disease_results = relationship("DiseaseResult", back_populates="farmer")
    orders = relationship("Order", back_populates="farmer")
    appointments = relationship("Appointment", back_populates="farmer")


class CropHistory(Base):
    __tablename__ = "crop_history"
    id = Column(Integer, primary_key=True)
    farmer_id = Column(Integer, ForeignKey("farmers.id"), nullable=False)
    crop_type = Column(String(50))
    season = Column(String(20))             # Kharif | Rabi | Zaid
    yield_amount = Column(Float)
    fertilizer_used = Column(String(100))
    quantity = Column(Float)                # amount grown/sold (e.g. kg, quintal)
    price = Column(Float)                   # price per unit the farmer recorded
    crop_date = Column(String(20))          # date the farmer logged (ISO yyyy-mm-dd)
    created_at = Column(DateTime, default=datetime.utcnow)

    farmer = relationship("Farmer", back_populates="crop_history")


# ─────────────────────────── ML result records ───────────────────────────
class FertilizerPrediction(Base):
    __tablename__ = "fertilizer_predictions"
    id = Column(Integer, primary_key=True)
    farmer_id = Column(Integer, ForeignKey("farmers.id"), nullable=False)
    input_data = Column(JSONB)              # the raw features sent to the model
    predicted_fertilizer = Column(String(100))
    confidence = Column(Float)
    created_at = Column(DateTime, default=datetime.utcnow)

    farmer = relationship("Farmer", back_populates="fertilizer_predictions")


class DiseaseResult(Base):
    __tablename__ = "disease_results"
    id = Column(Integer, primary_key=True)
    farmer_id = Column(Integer, ForeignKey("farmers.id"), nullable=False)
    image_url = Column(Text)
    disease_name = Column(String(100))
    confidence = Column(Float)
    created_at = Column(DateTime, default=datetime.utcnow)

    farmer = relationship("Farmer", back_populates="disease_results")


# ─────────────────────────── Community ───────────────────────────
class Post(Base):
    __tablename__ = "posts"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    text = Column(Text)
    image_url = Column(Text)
    likes = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)

    author = relationship("User", back_populates="posts")
    comments = relationship("Comment", back_populates="post", cascade="all, delete-orphan")


class Comment(Base):
    __tablename__ = "comments"
    id = Column(Integer, primary_key=True)
    post_id = Column(Integer, ForeignKey("posts.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    comment = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

    post = relationship("Post", back_populates="comments")
    author = relationship("User", back_populates="comments")


# ─────────────────────────── Seller / commerce ───────────────────────────
class Product(Base):
    __tablename__ = "products"
    id = Column(Integer, primary_key=True)
    seller_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    name = Column(String(100), nullable=False)
    type = Column(String(50))               # fertilizer | pesticide | seed | tool
    price = Column(Float)
    stock = Column(Integer, default=0)
    region_id = Column(Integer, ForeignKey("regions.id"))

    seller = relationship("User", back_populates="products")
    orders = relationship("Order", back_populates="product")


class Order(Base):
    __tablename__ = "orders"
    id = Column(Integer, primary_key=True)
    farmer_id = Column(Integer, ForeignKey("farmers.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    quantity = Column(Integer, default=1)
    status = Column(Enum(OrderStatus), default=OrderStatus.pending)
    created_at = Column(DateTime, default=datetime.utcnow)

    farmer = relationship("Farmer", back_populates="orders")
    product = relationship("Product", back_populates="orders")


# ─────────────────────────── Consultations / appointments ───────────────────────────
class Appointment(Base):
    """A consultation a farmer OR seller books with the analyst.

    The analyst is the single, system-seeded oversight account. We snapshot the
    analyst's id + name onto the booking (rather than a foreign key) so the row
    stays readable even if the account changes.

    `requester_id` (the user who booked) + `requester_role` work for both
    farmers and sellers. `farmer_id` is kept (nullable) so a farmer's booking
    still links back to their farmer profile.
    """
    __tablename__ = "appointments"
    id = Column(Integer, primary_key=True)
    requester_id = Column(Integer, ForeignKey("users.id"))  # who booked (farmer/seller)
    requester_role = Column(Enum(Role))                     # farmer | seller
    farmer_id = Column(Integer, ForeignKey("farmers.id"), nullable=True)
    expert_id = Column(Integer, nullable=False)             # the analyst's user id
    expert_name = Column(String(100), nullable=False)       # the analyst's name
    scheduled_date = Column(String(20), nullable=False)     # ISO yyyy-mm-dd
    scheduled_time = Column(String(10))                     # HH:MM (optional)
    topic = Column(Text)                                    # the problem described
    status = Column(Enum(AppointmentStatus), default=AppointmentStatus.pending)
    created_at = Column(DateTime, default=datetime.utcnow)

    farmer = relationship("Farmer", back_populates="appointments")
    requester = relationship("User")


# ─────────────────────────── Disaster broadcasts (analyst → region) ───────────────────────────
class Broadcast(Base):
    """A disaster/early-warning alert the analyst pushes out to a region.

    Created only by the single oversight analyst account; read by farmers and
    sellers so they can plan around floods, cyclones, pest/disease outbreaks etc.
    A null `region_id` means the alert applies to every region.
    """
    __tablename__ = "broadcasts"
    id = Column(Integer, primary_key=True)
    title = Column(String(150), nullable=False)
    category = Column(Enum(BroadcastCategory), nullable=False)
    description = Column(Text)
    region_id = Column(Integer, ForeignKey("regions.id"), nullable=True)  # null = all regions
    severity = Column(Enum(Severity), default=Severity.medium, nullable=False)
    event_date = Column(String(20))                         # ISO yyyy-mm-dd (when it hits)
    created_by_analyst = Column(Integer, nullable=False)    # the analyst's user id
    created_at = Column(DateTime, default=datetime.utcnow)

    region = relationship("Region", back_populates="broadcasts")
