"""
Reusable FastAPI dependencies = the AUTH + RBAC middleware from the report.

- get_current_user : decodes the JWT, loads the User from DB.   (Authentication)
- require_role(...) : factory that allows only the given role(s). (Authorization)

Usage in a route:
    @router.get("/seller/dashboard")
    def dash(user: User = Depends(require_role(Role.seller))):
        ...
"""
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Role, User
from app.security import decode_access_token

# tokenUrl points to the login route -> enables the "Authorize" button in /docs.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    creds_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    payload = decode_access_token(token)
    if not payload or "sub" not in payload:
        raise creds_error

    user = db.query(User).filter(User.id == int(payload["sub"])).first()
    if not user or not user.is_active:
        raise creds_error
    return user


def require_role(*allowed: Role):
    """Returns a dependency that 403s unless the user has one of `allowed` roles."""
    def checker(user: User = Depends(get_current_user)) -> User:
        if user.role not in allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied: requires role {[r.value for r in allowed]}",
            )
        return user
    return checker
