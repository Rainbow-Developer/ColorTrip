"""add shares.region_id

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-08-03
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "b2c3d4e5f6a7"
down_revision: str | Sequence[str] | None = "a1b2c3d4e5f6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("shares", sa.Column("region_id", sa.UUID(), nullable=True))
    op.create_foreign_key("fk_shares_region_id_regions", "shares", "regions", ["region_id"], ["id"])
    op.create_index("ix_shares_region_id", "shares", ["region_id"])


def downgrade() -> None:
    op.drop_index("ix_shares_region_id", table_name="shares")
    op.drop_constraint("fk_shares_region_id_regions", "shares", type_="foreignkey")
    op.drop_column("shares", "region_id")
