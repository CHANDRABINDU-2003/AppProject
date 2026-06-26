"""
Disaster broadcast routes.

The single oversight analyst account pushes out early-warning alerts (flood,
cyclone, heavy rain, pest outbreak, disease outbreak) to a region — or to every
region. Farmers and sellers read these so they can plan around the hazard.

  POST /broadcasts            (analyst)        create an alert
  GET  /broadcasts            (any logged-in)  list alerts (newest first)
  GET  /broadcasts/region/{id}(any logged-in)  alerts for one region + all-region alerts
  DELETE /broadcasts/{id}     (analyst)        withdraw an alert
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user, require_role
from app.models import Broadcast, Region, Role, User
from app.schemas import BroadcastIn, BroadcastOut

router = APIRouter(prefix="/broadcasts", tags=["broadcasts"])

analyst_only = require_role(Role.analyst)


def _to_out(b: Broadcast) -> BroadcastOut:
    """Attach the region name (or "All regions") for a friendlier payload."""
    out = BroadcastOut.model_validate(b)
    out.region_name = b.region.region_name if b.region else None
    return out


@router.post("", response_model=BroadcastOut, status_code=201)
def create_broadcast(
    payload: BroadcastIn,
    db: Session = Depends(get_db),
    user: User = Depends(analyst_only),
):
    if payload.region_id is not None:
        if not db.query(Region).filter(Region.id == payload.region_id).first():
            raise HTTPException(status_code=404, detail="Region not found")
    b = Broadcast(created_by_analyst=user.id, **payload.model_dump())
    db.add(b)
    db.commit()
    db.refresh(b)
    return _to_out(b)


@router.get("", response_model=list[BroadcastOut])
def list_broadcasts(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    rows = db.query(Broadcast).order_by(Broadcast.created_at.desc()).all()
    return [_to_out(b) for b in rows]


@router.get("/region/{region_id}", response_model=list[BroadcastOut])
def broadcasts_for_region(
    region_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Alerts targeting this region, plus alerts addressed to all regions."""
    rows = (
        db.query(Broadcast)
        .filter(
            (Broadcast.region_id == region_id) | (Broadcast.region_id.is_(None))
        )
        .order_by(Broadcast.created_at.desc())
        .all()
    )
    return [_to_out(b) for b in rows]


@router.delete("/{broadcast_id}", status_code=204)
def delete_broadcast(
    broadcast_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(analyst_only),
):
    b = db.query(Broadcast).filter(Broadcast.id == broadcast_id).first()
    if not b:
        raise HTTPException(status_code=404, detail="Broadcast not found")
    db.delete(b)
    db.commit()
