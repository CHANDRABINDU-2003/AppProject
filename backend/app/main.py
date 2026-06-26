"""
AgriPulse Core Backend — FastAPI entry point ("Core Engine" in the diagram).

Run from the backend/ folder:
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

Interactive API docs:  http://localhost:8000/docs
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import Base, engine
from app.routes import (
    analyst, appointments, assistant, auth, broadcast, common, community,
    farmer, marketplace, seller, weather,
)

# Dev convenience: create tables if they don't exist.
# For production / schema changes use Alembic migrations instead.
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="AgriPulse Core Backend",
    version="1.0.0",
    description="Auth + RBAC + business logic for farmers and sellers (analyst oversight).",
)

# Allow the Flutter app (web/mobile) to call this API.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],            # tighten to your real domain before production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["health"])
def health():
    return {"status": "ok", "service": "agripulse-core"}


# Register all routers.
app.include_router(auth.router)
app.include_router(common.router)
app.include_router(farmer.router)
app.include_router(seller.router)
app.include_router(community.router)
app.include_router(marketplace.router)
app.include_router(assistant.router)
app.include_router(weather.router)
app.include_router(appointments.router)
app.include_router(broadcast.router)
app.include_router(analyst.router)
