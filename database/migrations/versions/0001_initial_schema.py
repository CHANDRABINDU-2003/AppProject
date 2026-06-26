"""initial schema — all AgriPulse tables

Revision ID: 0001_initial
Revises:
Create Date: 2026-06-16

Mirrors backend/app/models.py and database/schema/schema.sql.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Enum types (created explicitly so downgrade can drop them cleanly).
# farmer + seller self-register; analyst is a single pre-provisioned account.
role = postgresql.ENUM("farmer", "seller", "analyst", name="role")
order_status = postgresql.ENUM(
    "pending", "confirmed", "shipped", "delivered", "cancelled", name="orderstatus"
)


def upgrade() -> None:
    bind = op.get_bind()
    role.create(bind, checkfirst=True)
    order_status.create(bind, checkfirst=True)

    op.create_table(
        "regions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("region_name", sa.String(100), nullable=False, unique=True),
    )

    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("email", sa.String(100), nullable=False),
        sa.Column("password_hash", sa.Text(), nullable=False),
        sa.Column("role", role, nullable=False),
        sa.Column("region_id", sa.Integer(), sa.ForeignKey("regions.id"), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    op.create_index("ix_users_role", "users", ["role"])

    op.create_table(
        "farmers",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False, unique=True),
        sa.Column("farm_size", sa.Float()),
        sa.Column("soil_type", sa.String(50)),
        sa.Column("main_crop", sa.String(50)),
    )

    op.create_table(
        "crop_history",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("farmer_id", sa.Integer(), sa.ForeignKey("farmers.id"), nullable=False),
        sa.Column("crop_type", sa.String(50)),
        sa.Column("season", sa.String(20)),
        sa.Column("yield_amount", sa.Float()),
        sa.Column("fertilizer_used", sa.String(100)),
        sa.Column("quantity", sa.Float()),
        sa.Column("price", sa.Float()),
        sa.Column("crop_date", sa.String(20)),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )

    op.create_table(
        "fertilizer_predictions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("farmer_id", sa.Integer(), sa.ForeignKey("farmers.id"), nullable=False),
        sa.Column("input_data", postgresql.JSONB()),
        sa.Column("predicted_fertilizer", sa.String(100)),
        sa.Column("confidence", sa.Float()),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )

    op.create_table(
        "disease_results",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("farmer_id", sa.Integer(), sa.ForeignKey("farmers.id"), nullable=False),
        sa.Column("image_url", sa.Text()),
        sa.Column("disease_name", sa.String(100)),
        sa.Column("confidence", sa.Float()),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )

    op.create_table(
        "posts",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("text", sa.Text()),
        sa.Column("image_url", sa.Text()),
        sa.Column("likes", sa.Integer(), server_default="0"),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )

    op.create_table(
        "comments",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("post_id", sa.Integer(), sa.ForeignKey("posts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("comment", sa.Text()),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )

    op.create_table(
        "products",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("seller_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("type", sa.String(50)),
        sa.Column("price", sa.Float()),
        sa.Column("stock", sa.Integer(), server_default="0"),
        sa.Column("region_id", sa.Integer(), sa.ForeignKey("regions.id")),
    )

    op.create_table(
        "orders",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("farmer_id", sa.Integer(), sa.ForeignKey("farmers.id"), nullable=False),
        sa.Column("product_id", sa.Integer(), sa.ForeignKey("products.id"), nullable=False),
        sa.Column("quantity", sa.Integer(), server_default="1"),
        sa.Column("status", order_status, server_default="pending"),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )


def downgrade() -> None:
    for table in (
        "orders", "products", "comments", "posts",
        "disease_results", "fertilizer_predictions", "crop_history",
        "farmers", "users", "regions",
    ):
        op.drop_table(table)

    bind = op.get_bind()
    order_status.drop(bind, checkfirst=True)
    role.drop(bind, checkfirst=True)
