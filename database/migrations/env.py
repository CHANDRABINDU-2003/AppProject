"""
Alembic environment for the AgriPulse database.

It reuses the backend's SQLAlchemy models as the single source of truth for the
schema (target_metadata = Base.metadata), so `alembic revision --autogenerate`
diffs real model changes, and one DATABASE_URL is shared with the FastAPI app.
"""
import os
import sys
from logging.config import fileConfig
from pathlib import Path

from alembic import context
from sqlalchemy import engine_from_config, pool

# ── Make the backend importable (database/migrations -> repo root -> backend) ──
REPO_ROOT = Path(__file__).resolve().parents[2]
BACKEND_DIR = REPO_ROOT / "backend"
sys.path.insert(0, str(BACKEND_DIR))

from app.database import Base          # noqa: E402  (path set above)
from app import models                 # noqa: E402,F401  (register all tables)

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def _database_url() -> str:
    """Prefer DATABASE_URL from the env; otherwise fall back to backend settings."""
    if os.getenv("DATABASE_URL"):
        return os.environ["DATABASE_URL"]
    from app.config import settings     # noqa: E402
    return settings.DATABASE_URL


def run_migrations_offline() -> None:
    context.configure(
        url=_database_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    section = config.get_section(config.config_ini_section) or {}
    section["sqlalchemy.url"] = _database_url()
    connectable = engine_from_config(
        section, prefix="sqlalchemy.", poolclass=pool.NullPool
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
