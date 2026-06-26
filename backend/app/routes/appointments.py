"""
Appointment routes — farmers AND sellers book consultations with the analyst.

The analyst is the single, system-seeded oversight account (see app/seed.py);
it is never registerable. A farmer or seller books a consultation by choosing a
date and describing their problem; each can list and cancel their own requests.
The analyst sees every request — including who asked (farmer or seller).
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import require_role
from app.models import Appointment, AppointmentStatus, Farmer, Role, User
from app.schemas import (
    AppointmentAdminOut, AppointmentIn, AppointmentOut, AppointmentStatusUpdate,
)

router = APIRouter(prefix="/appointments", tags=["appointments"])

# Both registerable roles may consult the analyst.
requester_only = require_role(Role.farmer, Role.seller)
analyst_only = require_role(Role.analyst)


def _analyst(db: Session) -> User:
    analyst = db.query(User).filter(User.role == Role.analyst).first()
    if not analyst:
        raise HTTPException(status_code=503, detail="No analyst account available")
    return analyst


@router.post("", response_model=AppointmentOut, status_code=201)
def book_appointment(
    payload: AppointmentIn,
    db: Session = Depends(get_db),
    user: User = Depends(requester_only),
):
    analyst = _analyst(db)

    # A farmer booking also links to their farmer profile; a seller has none.
    farmer_id = None
    if user.role == Role.farmer:
        farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
        farmer_id = farmer.id if farmer else None

    appt = Appointment(
        requester_id=user.id,
        requester_role=user.role,
        farmer_id=farmer_id,
        expert_id=analyst.id,
        expert_name=analyst.name,
        scheduled_date=payload.scheduled_date,
        topic=payload.topic,
    )
    db.add(appt)
    db.commit()
    db.refresh(appt)
    return appt


@router.get("", response_model=list[AppointmentOut])
def my_appointments(
    db: Session = Depends(get_db),
    user: User = Depends(requester_only),
):
    return (
        db.query(Appointment)
        .filter(Appointment.requester_id == user.id)
        .order_by(Appointment.created_at.desc())
        .all()
    )


@router.put("/{appointment_id}/cancel", response_model=AppointmentOut)
def cancel_appointment(
    appointment_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(requester_only),
):
    appt = (
        db.query(Appointment)
        .filter(
            Appointment.id == appointment_id,
            Appointment.requester_id == user.id,
        )
        .first()
    )
    if not appt:
        raise HTTPException(status_code=404, detail="Appointment not found")

    appt.status = AppointmentStatus.cancelled
    db.commit()
    db.refresh(appt)
    return appt


# ─────────── Analyst-side management (Appointment Management) ───────────
@router.get("/all", response_model=list[AppointmentAdminOut])
def all_appointments(
    db: Session = Depends(get_db),
    user: User = Depends(analyst_only),
):
    """Every consultation request, newest first — the analyst's queue.

    Each row carries who requested it (farmer or seller) and their role.
    """
    appts = db.query(Appointment).order_by(Appointment.created_at.desc()).all()
    out: list[AppointmentAdminOut] = []
    for a in appts:
        row = AppointmentAdminOut.model_validate(a)

        # Resolve the requesting user. Prefer the explicit requester link; fall
        # back to the farmer profile for older farmer-only bookings.
        requester = (
            db.query(User).filter(User.id == a.requester_id).first()
            if a.requester_id else None
        )
        if requester is None and a.farmer_id:
            farmer = db.query(Farmer).filter(Farmer.id == a.farmer_id).first()
            requester = farmer.user if farmer else None

        if requester:
            row.requester_name = requester.name
            row.requester_role = a.requester_role or requester.role
            row.farmer_name = requester.name  # backward-compatible field
        out.append(row)
    return out


@router.put("/{appointment_id}/status", response_model=AppointmentOut)
def set_appointment_status(
    appointment_id: int,
    payload: AppointmentStatusUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(analyst_only),
):
    """Analyst accepts (confirmed), rejects (cancelled) or completes a request."""
    appt = db.query(Appointment).filter(Appointment.id == appointment_id).first()
    if not appt:
        raise HTTPException(status_code=404, detail="Appointment not found")
    appt.status = payload.status
    db.commit()
    db.refresh(appt)
    return appt
