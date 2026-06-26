"""
SQLAlchemy engine + session.  This is the bridge between FastAPI and PostgreSQL.

- `Base`        -> every model inherits from this.
- `SessionLocal`-> a new DB session per request.
- `get_db()`    -> FastAPI dependency that opens/closes a session safely.
"""
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.config import settings

engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """Yields a DB session and guarantees it is closed afterwards."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
