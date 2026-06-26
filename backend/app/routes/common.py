"""Shared lookup routes (no role restriction beyond being logged in)."""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Region
from app.schemas import RegionOut

router = APIRouter(tags=["common"])


@router.get("/regions", response_model=list[RegionOut])
def list_regions(db: Session = Depends(get_db)):
    """Public — Flutter needs this to populate the region dropdown at signup."""
    return db.query(Region).order_by(Region.id).all()
