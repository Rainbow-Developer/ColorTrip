"""add_travel_timeline_table

Revision ID: 9c0244355f03
Revises: a4f2c8d1e9b0
Create Date: 2026-07-20 21:16:59.520329

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '9c0244355f03'
down_revision: Union[str, Sequence[str], None] = 'a4f2c8d1e9b0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "timelines",
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("region_id", sa.UUID(), nullable=True),
        sa.Column("quest_progress_id", sa.UUID(), nullable=True),
        sa.Column("event_type", sa.String(length=30), nullable=False),
        sa.Column("title", sa.String(length=100), nullable=True),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["region_id"], ["regions.id"]),
        sa.ForeignKeyConstraint(["quest_progress_id"], ["quest_progress.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_timelines_user_occurred", "timelines", ["user_id", "occurred_at"])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_timelines_user_occurred", table_name="timelines")
    op.drop_table("timelines")
