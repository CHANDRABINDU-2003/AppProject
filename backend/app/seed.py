"""
Seed the database from database/seed/data/*.csv.

Run from the backend/ folder (after the DB is up):
    python -m app.seed

Idempotent-ish: it skips rows whose unique key already exists, so re-running
won't create duplicate users/regions. Wipe with `python -m app.seed --reset`.
"""
import csv
import sys
from pathlib import Path

from app.database import Base, SessionLocal, engine
from app.models import (
    Broadcast, BroadcastCategory, Comment, CropHistory, CropMaster,
    DiseaseMaster, Farmer, FertilizerMaster, Order, OrderStatus, Post,
    Product, Region, Role, Severity, User,
)
from app.security import hash_password

# Seed CSVs live in the dedicated database/ folder (repo_root/database/seed/data).
DATA = Path(__file__).resolve().parents[2] / "database" / "seed" / "data"


def _rows(filename: str):
    with open(DATA / filename, newline="", encoding="utf-8") as f:
        yield from csv.DictReader(f)


def _f(value: str | None) -> float | None:
    """Parse an optional float CSV cell ('' → None). Tolerates app-appended rows
    that leave some numeric columns blank."""
    value = (value or "").strip()
    return float(value) if value else None


def seed():
    db = SessionLocal()
    try:
        # 1) Regions ──────────────────────────────────────────────
        for r in _rows("regions.csv"):
            if not db.query(Region).filter_by(region_name=r["region_name"]).first():
                db.add(Region(region_name=r["region_name"]))
        db.commit()

        # 2) Users (+ empty farmer profiles) ──────────────────────
        for u in _rows("users.csv"):
            if db.query(User).filter_by(email=u["email"]).first():
                continue
            user = User(
                name=u["name"],
                email=u["email"],
                password_hash=hash_password(u["password"]),
                role=Role(u["role"]),
                region_id=int(u["region_id"]) if u["region_id"] else None,
            )
            db.add(user)
            db.flush()
            if user.role == Role.farmer:
                db.add(Farmer(user_id=user.id))
        db.commit()

        # Helper maps (email -> id) built once after users exist.
        users = {u.email: u for u in db.query(User).all()}
        farmers = {                                # email -> Farmer
            u.email: db.query(Farmer).filter_by(user_id=u.id).first()
            for u in users.values() if u.role == Role.farmer
        }

        # 3) Farmer profile details ───────────────────────────────
        for f in _rows("farmers.csv"):
            prof = farmers.get(f["email"])
            if prof:
                prof.farm_size = float(f["farm_size"])
                prof.soil_type = f["soil_type"]
                prof.main_crop = f["main_crop"]
        db.commit()

        # 4) Crop history ─────────────────────────────────────────
        for c in _rows("crop_history.csv"):
            prof = farmers.get(c["email"])
            if prof:
                db.add(CropHistory(
                    farmer_id=prof.id, crop_type=c["crop_type"], season=c["season"],
                    yield_amount=_f(c.get("yield_amount")),
                    fertilizer_used=c.get("fertilizer_used") or None,
                    quantity=_f(c.get("quantity")),
                    price=_f(c.get("price")),
                    crop_date=(c.get("crop_date") or "").strip() or None,
                ))
        db.commit()

        # 5) Products (by seller) ─────────────────────────────────
        for p in _rows("products.csv"):
            seller = users.get(p["seller_email"])
            if seller:
                db.add(Product(
                    seller_id=seller.id, name=p["name"], type=p["type"],
                    price=float(p["price"]), stock=int(p["stock"]),
                    region_id=int(p["region_id"]) if p["region_id"] else None,
                ))
        db.commit()

        products = {p.name: p for p in db.query(Product).all()}

        # 6) Orders (farmer -> product) ───────────────────────────
        for o in _rows("orders.csv"):
            prof = farmers.get(o["farmer_email"])
            prod = products.get(o["product_name"])
            if prof and prod:
                db.add(Order(
                    farmer_id=prof.id, product_id=prod.id,
                    quantity=int(o["quantity"]), status=OrderStatus(o["status"]),
                ))
        db.commit()

        # 7) Posts ────────────────────────────────────────────────
        for p in _rows("posts.csv"):
            author = users.get(p["email"])
            if author:
                db.add(Post(user_id=author.id, text=p["text"], likes=int(p["likes"])))
        db.commit()

        posts = db.query(Post).all()

        # 8) Comments (matched to a post by text prefix) ──────────
        for c in _rows("comments.csv"):
            author = users.get(c["email"])
            target = next(
                (p for p in posts if (p.text or "").startswith(c["post_text_startswith"])),
                None,
            )
            if author and target:
                db.add(Comment(post_id=target.id, user_id=author.id, comment=c["comment"]))
        db.commit()

        # 9) Disaster broadcasts (by the analyst) ─────────────────
        analyst = next(
            (u for u in users.values() if u.role == Role.analyst), None
        )
        regions = {r.region_name: r for r in db.query(Region).all()}
        if analyst and db.query(Broadcast).count() == 0:
            for b in _rows("broadcasts.csv"):
                region = regions.get(b["region_name"]) if b["region_name"] else None
                db.add(Broadcast(
                    title=b["title"],
                    category=BroadcastCategory(b["category"]),
                    description=b["description"],
                    region_id=region.id if region else None,
                    severity=Severity(b["severity"]),
                    event_date=b["event_date"] or None,
                    created_by_analyst=analyst.id,
                ))
            db.commit()

        # 10) Knowledge masters (crop / disease / fertilizer reference) ──
        # Searched before the chatbot runs to ground its answers (see
        # app/services/knowledge.py). Keyed by unique name, so re-running skips.
        for c in _rows("crop_master.csv"):
            if not db.query(CropMaster).filter_by(name=c["name"]).first():
                db.add(CropMaster(
                    name=c["name"], description=c.get("description") or None,
                    season=c.get("season") or None,
                    water_requirement=c.get("water_requirement") or None,
                ))
        for d in _rows("disease_master.csv"):
            if not db.query(DiseaseMaster).filter_by(name=d["name"]).first():
                db.add(DiseaseMaster(
                    name=d["name"], symptoms=d.get("symptoms") or None,
                    solution=d.get("solution") or None,
                ))
        for fz in _rows("fertilizer_master.csv"):
            if not db.query(FertilizerMaster).filter_by(name=fz["name"]).first():
                db.add(FertilizerMaster(
                    name=fz["name"], used_for=fz.get("used_for") or None,
                ))
        db.commit()

        print("✅ Seed complete.")
        print(f"   regions={db.query(Region).count()} users={db.query(User).count()} "
              f"farmers={db.query(Farmer).count()} products={db.query(Product).count()} "
              f"orders={db.query(Order).count()} posts={db.query(Post).count()} "
              f"broadcasts={db.query(Broadcast).count()} "
              f"crops={db.query(CropMaster).count()} "
              f"diseases={db.query(DiseaseMaster).count()} "
              f"fertilizers={db.query(FertilizerMaster).count()}")
        print("\n   Log in with a seeded account, e.g.:")
        print("     Farmer  → email: farmer1@agripulse.com  password: Pass1234")
        print("     Seller  → email: seller1@agripulse.com  password: Pass1234")
        print("     Analyst → email: udita@gmail.com        password: 2102006")
    finally:
        db.close()


def reset():
    """Drop and recreate all tables (DANGER: wipes data)."""
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    print("🗑️  Database reset (all tables dropped & recreated).")


if __name__ == "__main__":
    if "--reset" in sys.argv:
        reset()
    Base.metadata.create_all(bind=engine)
    seed()
