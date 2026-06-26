"""crop / disease / fertilizer knowledge master tables

Revision ID: 0003_master_tables
Revises: 0002_appointments_broadcasts
Create Date: 2026-06-23

Adds the curated reference tables (`crop_master`, `disease_master`,
`fertilizer_master`) that the assistant searches before the FLAN-T5 chatbot
runs, so answers are grounded in real facts (a small RAG step). Mirrors
backend/app/models.py and database/schema/schema.sql.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0003_master_tables"
down_revision: Union[str, None] = "0002_appointments_broadcasts"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "crop_master",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(100), nullable=False, unique=True),
        sa.Column("description", sa.Text()),
        sa.Column("season", sa.String(100)),
        sa.Column("water_requirement", sa.String(100)),
    )
    op.create_index("ix_crop_master_name", "crop_master", ["name"])

    op.create_table(
        "disease_master",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(200), nullable=False, unique=True),
        sa.Column("symptoms", sa.Text()),
        sa.Column("solution", sa.Text()),
    )
    op.create_index("ix_disease_master_name", "disease_master", ["name"])

    op.create_table(
        "fertilizer_master",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(100), nullable=False, unique=True),
        sa.Column("used_for", sa.Text()),
    )
    op.create_index("ix_fertilizer_master_name", "fertilizer_master", ["name"])


def downgrade() -> None:
    op.drop_index("ix_fertilizer_master_name", table_name="fertilizer_master")
    op.drop_table("fertilizer_master")
    op.drop_index("ix_disease_master_name", table_name="disease_master")
    op.drop_table("disease_master")
    op.drop_index("ix_crop_master_name", table_name="crop_master")
    op.drop_table("crop_master")
