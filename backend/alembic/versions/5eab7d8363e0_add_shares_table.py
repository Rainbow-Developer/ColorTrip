"""add_shares_table

Revision ID: 5eab7d8363e0
Revises: 9c0244355f03
Create Date: 2026-07-21 21:59:43.023109

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5eab7d8363e0'
down_revision: Union[str, Sequence[str], None] = '9c0244355f03'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "shares",
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("share_code", sa.String(length=16), nullable=False),
        sa.Column("share_style", sa.String(length=20), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("share_code", name="uq_shares_share_code"),
    )
    op.create_index("ix_shares_share_code", "shares", ["share_code"], unique=True)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_shares_share_code", table_name="shares")
    op.drop_table("shares")
