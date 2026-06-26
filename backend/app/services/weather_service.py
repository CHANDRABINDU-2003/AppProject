"""
Location-based weather + environmental-disaster alerts.

Uses the free, key-less Open-Meteo API (https://open-meteo.com) so it works out
of the box with no signup. Given a farmer's latitude/longitude we fetch the
current conditions and a short forecast, then derive plain-language disaster
"alarms" (flood, extreme heat, storm, frost, thunderstorm) from threshold rules
a farmer cares about.
"""
from __future__ import annotations

import httpx

_FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
TIMEOUT = 15.0

# WMO weather-interpretation codes → short human description.
_WMO = {
    0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
    45: "Fog", 48: "Rime fog",
    51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle",
    61: "Light rain", 63: "Rain", 65: "Heavy rain",
    66: "Freezing rain", 67: "Heavy freezing rain",
    71: "Light snow", 73: "Snow", 75: "Heavy snow", 77: "Snow grains",
    80: "Rain showers", 81: "Heavy rain showers", 82: "Violent rain showers",
    85: "Snow showers", 86: "Heavy snow showers",
    95: "Thunderstorm", 96: "Thunderstorm with hail", 99: "Severe thunderstorm with hail",
}


def _describe(code: int | None) -> str:
    return _WMO.get(int(code), "Unknown") if code is not None else "Unknown"


def _derive_alerts(current: dict, daily: list[dict]) -> list[dict]:
    """Turn raw forecast numbers into farmer-facing disaster alerts."""
    alerts: list[dict] = []

    def add(atype: str, severity: str, title: str, message: str) -> None:
        alerts.append({"type": atype, "severity": severity,
                       "title": title, "message": message})

    for day in daily:
        when = day["date"]
        rain = day.get("precip") or 0
        wind = day.get("wind_max") or 0
        tmax = day.get("temp_max")
        tmin = day.get("temp_min")
        code = day.get("code")

        # Heavy rain / flooding.
        if rain >= 100:
            add("flood", "critical", "Severe flooding risk",
                f"Very heavy rain (~{rain:.0f} mm) expected {when}. Clear drainage "
                "channels, move stored harvest to high ground and avoid spraying.")
        elif rain >= 50:
            add("flood", "high", "Heavy rainfall / flood risk",
                f"Heavy rain (~{rain:.0f} mm) expected {when}. Improve field "
                "drainage and hold off on fertiliser that could wash away.")

        # Extreme heat.
        if tmax is not None and tmax >= 45:
            add("heat", "critical", "Extreme heat warning",
                f"Temperatures near {tmax:.0f}°C on {when}. Irrigate in the cool "
                "hours, mulch to protect roots and shade young plants.")
        elif tmax is not None and tmax >= 40:
            add("heat", "high", "Heatwave",
                f"Hot day (~{tmax:.0f}°C) on {when}. Water early morning/evening "
                "and watch livestock and seedlings for heat stress.")

        # High wind / storm.
        if wind >= 90:
            add("storm", "critical", "Destructive winds",
                f"Wind gusts up to {wind:.0f} km/h on {when}. Stake tall crops and "
                "secure greenhouses, sheds and equipment.")
        elif wind >= 60:
            add("storm", "high", "High winds",
                f"Strong winds (~{wind:.0f} km/h) on {when}. Stake plants and delay "
                "spraying or foliar feeding.")

        # Frost.
        if tmin is not None and tmin <= 0:
            add("frost", "high", "Frost warning",
                f"Frost likely (~{tmin:.0f}°C) on {when}. Cover seedlings overnight "
                "and irrigate lightly beforehand — moist soil holds heat.")
        elif tmin is not None and tmin <= 3:
            add("frost", "medium", "Cold / possible frost",
                f"Cold night (~{tmin:.0f}°C) on {when}. Protect tender crops.")

        # Thunderstorms.
        if code in (95, 96, 99):
            add("thunderstorm", "high", "Thunderstorm expected",
                f"{_describe(code)} on {when}. Stay out of open fields during the "
                "storm and secure loose equipment.")

    # De-duplicate by (type, severity) so a 3-day forecast doesn't repeat the
    # same warning three times — keep the first (soonest) occurrence.
    seen: set[tuple[str, str]] = set()
    unique: list[dict] = []
    for a in alerts:
        key = (a["type"], a["severity"])
        if key not in seen:
            seen.add(key)
            unique.append(a)
    return unique


async def get_alerts(lat: float, lon: float) -> dict:
    """Fetch conditions for a coordinate and return current + forecast + alerts."""
    params = {
        "latitude": lat,
        "longitude": lon,
        "current": "temperature_2m,relative_humidity_2m,precipitation,"
                   "weather_code,wind_speed_10m",
        "daily": "weather_code,temperature_2m_max,temperature_2m_min,"
                 "precipitation_sum,wind_speed_10m_max,precipitation_probability_max",
        "timezone": "auto",
        "forecast_days": 3,
    }
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            r = await client.get(_FORECAST_URL, params=params)
            r.raise_for_status()
            data = r.json()
    except httpx.HTTPError as e:
        return {
            "latitude": lat, "longitude": lon, "available": False,
            "error": f"Weather service unavailable: {e}",
            "current": None, "daily": [], "alerts": [],
        }

    cur = data.get("current", {}) or {}
    current = {
        "temperature": cur.get("temperature_2m"),
        "humidity": cur.get("relative_humidity_2m"),
        "precipitation": cur.get("precipitation"),
        "wind_speed": cur.get("wind_speed_10m"),
        "code": cur.get("weather_code"),
        "description": _describe(cur.get("weather_code")),
    }

    d = data.get("daily", {}) or {}
    dates = d.get("time", []) or []
    daily = [
        {
            "date": dates[i],
            "code": (d.get("weather_code") or [None])[i],
            "description": _describe((d.get("weather_code") or [None])[i]),
            "temp_max": (d.get("temperature_2m_max") or [None])[i],
            "temp_min": (d.get("temperature_2m_min") or [None])[i],
            "precip": (d.get("precipitation_sum") or [None])[i],
            "precip_prob": (d.get("precipitation_probability_max") or [None])[i],
            "wind_max": (d.get("wind_speed_10m_max") or [None])[i],
        }
        for i in range(len(dates))
    ]

    return {
        "latitude": lat, "longitude": lon, "available": True,
        "current": current, "daily": daily,
        "alerts": _derive_alerts(current, daily),
    }
