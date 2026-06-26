"""
Weather + environmental-disaster alert route — available to ALL logged-in roles.

The client passes its geolocation (captured with the device's permission) and we
return current conditions, a short forecast and any disaster alarms (flood,
heat, storm, frost) derived for that location via the free Open-Meteo API.
"""
from fastapi import APIRouter, Depends, Query

from app.deps import get_current_user
from app.models import User
from app.services import weather_service

router = APIRouter(prefix="/weather", tags=["weather"])


@router.get("/alerts")
async def weather_alerts(
    lat: float = Query(..., ge=-90, le=90, description="Latitude"),
    lon: float = Query(..., ge=-180, le=180, description="Longitude"),
    user: User = Depends(get_current_user),
):
    """Current weather + forecast + disaster alerts for the given coordinate."""
    return await weather_service.get_alerts(lat, lon)
