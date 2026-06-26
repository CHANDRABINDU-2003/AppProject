"""
Auth routes: register + login.

Login flow (from the report):
  Login -> Validate -> Generate JWT -> Flutter stores token -> API requests use token
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models import Farmer, Role, User
from app.schemas import Token, UserCreate, UserOut
from app.security import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


# Only these roles can self-register. The analyst is a single, pre-provisioned
# oversight account (see app/seed.py) — it can never be created via the API.
REGISTERABLE_ROLES = {Role.farmer, Role.seller}


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register(payload: UserCreate, db: Session = Depends(get_db)):
    if payload.role not in REGISTERABLE_ROLES:
        raise HTTPException(
            status_code=400,
            detail="Only farmer and seller accounts can be registered.",
        )
    if db.query(User).filter(User.email == payload.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    user = User(
        name=payload.name,
        email=payload.email,
        password_hash=hash_password(payload.password),
        role=payload.role,
        region_id=payload.region_id,
    )
    db.add(user)
    db.flush()                      # get user.id before commit

    # A farmer automatically gets an (empty) farmer profile row.
    if user.role == Role.farmer:
        db.add(Farmer(user_id=user.id))

    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=Token)
def login(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    # OAuth2PasswordRequestForm uses `username` field — we treat it as the email.
    user = db.query(User).filter(User.email == form.username).first()
    if not user or not verify_password(form.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect email or password")

    token = create_access_token({"sub": str(user.id), "role": user.role.value})
    return Token(access_token=token, user=user)


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user
