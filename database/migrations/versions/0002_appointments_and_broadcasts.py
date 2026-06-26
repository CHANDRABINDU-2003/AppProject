"""appointments + disaster broadcasts

Revision ID: 0002_appointments_broadcasts
Revises: 0001_initial
Create Date: 2026-06-23

Adds the consultation `appointments` table and the disaster `broadcasts` table
(plus their enum types). Mirrors backend/app/models.py and
database/schema/schema.sql.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0002_appointments_broadcasts"
down_revision: Union[str, None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

appointment_status = postgresql.ENUM(
    "pending", "confirmed", "completed", "cancelled", name="appointmentstatus"
)
severity = postgresql.ENUM("low", "medium", "high", "critical", name="severity")
broadcast_category = postgresql.ENUM(
    "flood", "cyclone", "heavy_rain", "pest_outbreak", "disease_outbreak",
    name="broadcastcategory",
)


def upgrade() -> None:
    bind = op.get_bind()
    appointment_status.create(bind, checkfirst=True)
    severity.create(bind, checkfirst=True)
    broadcast_category.create(bind, checkfirst=True)

    op.create_table(
        "appointments",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("farmer_id", sa.Integer(), sa.ForeignKey("farmers.id"), nullable=False),
        sa.Column("expert_id", sa.Integer(), nullable=False),
        sa.Column("expert_name", sa.String(100), nullable=False),
        sa.Column("scheduled_date", sa.String(20), nullable=False),
        sa.Column("scheduled_time", sa.String(10)),
        sa.Column("topic", sa.Text()),
        sa.Column("status", appointment_status, server_default="pending"),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )

    op.create_table(
        "broadcasts",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("title", sa.String(150), nullable=False),
        sa.Column("category", broadcast_category, nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("region_id", sa.Integer(), sa.ForeignKey("regions.id"), nullable=True),
        sa.Column("severity", severity, server_default="medium", nullable=False),
        sa.Column("event_date", sa.String(20)),
        sa.Column("created_by_analyst", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("broadcasts")
    op.drop_table("appointments")

    bind = op.get_bind()
    broadcast_category.drop(bind, checkfirst=True)
    severity.drop(bind, checkfirst=True)
    appointment_status.drop(bind, checkfirst=True)
