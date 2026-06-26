"""
Seller routes (role = seller).

Seller flow:
  Login -> Product Upload -> Farmer Order -> Status Update -> Analytics

Sellers also get region-based visibility of nearby farmers (and farmers get the
mirror view of nearby sellers — see routes/farmer.py), so the two sides of the
marketplace can find each other by region.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import require_role
from app.models import Farmer, Order, Product, Region, Role, User
from app.schemas import (
    NearbyUserOut, OrderOut, OrderStatusUpdate, ProductIn, ProductOut,
    SellerOrderOut,
)

router = APIRouter(prefix="/seller", tags=["seller"])
seller_only = require_role(Role.seller)


# ─────────── Products ───────────
@router.post("/products", response_model=ProductOut, status_code=201)
def add_product(
    payload: ProductIn,
    db: Session = Depends(get_db),
    user: User = Depends(seller_only),
):
    product = Product(seller_id=user.id, **payload.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


@router.get("/products", response_model=list[ProductOut])
def my_products(db: Session = Depends(get_db), user: User = Depends(seller_only)):
    return db.query(Product).filter(Product.seller_id == user.id).all()


@router.put("/products/{product_id}", response_model=ProductOut)
def update_product(
    product_id: int,
    payload: ProductIn,
    db: Session = Depends(get_db),
    user: User = Depends(seller_only),
):
    product = db.query(Product).filter(
        Product.id == product_id, Product.seller_id == user.id
    ).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    for field, value in payload.model_dump().items():
        setattr(product, field, value)
    db.commit()
    db.refresh(product)
    return product


# ─────────── Orders ───────────
@router.get("/orders", response_model=list[SellerOrderOut])
def incoming_orders(db: Session = Depends(get_db), user: User = Depends(seller_only)):
    """Orders placed against this seller's products, enriched for stock planning:
    who ordered, the quantity, the order status and the buyer's region."""
    orders = (
        db.query(Order)
        .join(Product, Order.product_id == Product.id)
        .filter(Product.seller_id == user.id)
        .order_by(Order.created_at.desc())
        .all()
    )

    region_names = {r.id: r.region_name for r in db.query(Region).all()}
    out: list[SellerOrderOut] = []
    for o in orders:
        farmer = db.query(Farmer).filter(Farmer.id == o.farmer_id).first()
        buyer = farmer.user if farmer else None
        out.append(SellerOrderOut(
            id=o.id,
            product_id=o.product_id,
            product_name=o.product.name if o.product else None,
            quantity=o.quantity,
            status=o.status,
            farmer_name=buyer.name if buyer else None,
            region_name=region_names.get(buyer.region_id) if buyer else None,
            created_at=o.created_at,
        ))
    return out


@router.put("/orders/{order_id}/status", response_model=OrderOut)
def update_order_status(
    order_id: int,
    payload: OrderStatusUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(seller_only),
):
    order = (
        db.query(Order)
        .join(Product, Order.product_id == Product.id)
        .filter(Order.id == order_id, Product.seller_id == user.id)
        .first()
    )
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    order.status = payload.status
    db.commit()
    db.refresh(order)
    return order


# ─────────── Nearby farmers (region-based visibility) ───────────
@router.get("/nearby-farmers", response_model=list[NearbyUserOut])
def nearby_farmers(
    region_id: int | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(seller_only),
):
    """Farmers in the selected region (defaults to the seller's own region).

    Powers the seller dashboard's "nearby farmers" view — the mirror of the
    farmer's "nearby sellers" list.
    """
    target_region = region_id if region_id is not None else user.region_id
    q = db.query(User).filter(User.role == Role.farmer, User.is_active == True)  # noqa: E712
    if target_region is not None:
        q = q.filter(User.region_id == target_region)
    return q.order_by(User.name).all()


# ─────────── Analytics ───────────
@router.get("/analytics")
def analytics(db: Session = Depends(get_db), user: User = Depends(seller_only)):
    products = db.query(Product).filter(Product.seller_id == user.id).all()
    orders = (
        db.query(Order)
        .join(Product, Order.product_id == Product.id)
        .filter(Product.seller_id == user.id)
        .all()
    )
    earning_statuses = ("confirmed", "shipped", "delivered")
    revenue = sum(
        o.quantity * (o.product.price or 0)
        for o in orders
        if o.status.value in earning_statuses
    )

    # ── Graph series for the seller dashboard ──
    # Orders grouped by status (pie chart).
    orders_by_status: dict[str, int] = {}
    for o in orders:
        key = o.status.value
        orders_by_status[key] = orders_by_status.get(key, 0) + 1

    # Per-product revenue and current stock (bar charts). Revenue counts only
    # orders that actually earn money (confirmed/shipped/delivered).
    revenue_by_product: dict[int, float] = {}
    for o in orders:
        if o.status.value in earning_statuses and o.product:
            revenue_by_product[o.product_id] = (
                revenue_by_product.get(o.product_id, 0)
                + o.quantity * (o.product.price or 0)
            )

    product_revenue = [
        {"name": p.name, "revenue": round(revenue_by_product.get(p.id, 0), 2)}
        for p in products
    ]
    product_stock = [
        {"name": p.name, "stock": p.stock or 0} for p in products
    ]

    return {
        "total_products": len(products),
        "total_orders": len(orders),
        "low_stock": [p.name for p in products if (p.stock or 0) < 10],
        "estimated_revenue": round(revenue, 2),
        "orders_by_status": orders_by_status,
        "product_revenue": product_revenue,
        "product_stock": product_stock,
    }
