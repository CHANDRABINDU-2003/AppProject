"""
Marketplace routes — the farmer-facing side of commerce.
Farmers browse seller products (optionally filtered by region) and place orders.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user, require_role
from app.models import Farmer, Order, Product, Role, User
from app.schemas import OrderIn, OrderOut, ProductOut

router = APIRouter(prefix="/marketplace", tags=["marketplace"])


@router.get("/products", response_model=list[ProductOut])
def browse_products(
    region_id: int | None = None,
    type: str | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),     # any logged-in user can browse
):
    q = db.query(Product).filter(Product.stock > 0)
    if region_id is not None:
        q = q.filter(Product.region_id == region_id)
    if type is not None:
        q = q.filter(Product.type == type)
    return q.all()


@router.post("/orders", response_model=OrderOut, status_code=201)
def place_order(
    payload: OrderIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_role(Role.farmer)),
):
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found")

    product = db.query(Product).filter(Product.id == payload.product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if (product.stock or 0) < payload.quantity:
        raise HTTPException(status_code=400, detail="Not enough stock")

    product.stock -= payload.quantity            # decrement inventory
    order = Order(farmer_id=farmer.id, product_id=product.id, quantity=payload.quantity)
    db.add(order)
    db.commit()
    db.refresh(order)
    return order


@router.get("/orders", response_model=list[OrderOut])
def my_orders(
    db: Session = Depends(get_db),
    user: User = Depends(require_role(Role.farmer)),
):
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    return (
        db.query(Order)
        .filter(Order.farmer_id == farmer.id)
        .order_by(Order.created_at.desc())
        .all()
    )
