"""add journey and quest progress tables

Revision ID: f4b2a9c67e18
Revises: d7b712f1a245
Create Date: 2026-07-05 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "f4b2a9c67e18"
down_revision: Union[str, Sequence[str], None] = "d7b712f1a245"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "journeys",
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("region_id", sa.UUID(), nullable=False),
        sa.Column("title", sa.String(length=100), nullable=True),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["region_id"], ["regions.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_journeys_user_status", "journeys", ["user_id", "status"])

    op.create_table(
        "journey_quests",
        sa.Column("journey_id", sa.UUID(), nullable=False),
        sa.Column("quest_id", sa.UUID(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["journey_id"], ["journeys.id"]),
        sa.ForeignKeyConstraint(["quest_id"], ["quests.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "journey_id",
            "quest_id",
            name="uq_journey_quests_journey_id_quest_id",
        ),
    )

    op.create_table(
        "quest_progress",
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("quest_id", sa.UUID(), nullable=False),
        sa.Column("journey_id", sa.UUID(), nullable=True),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("verified_lat", sa.Numeric(precision=10, scale=7), nullable=True),
        sa.Column("verified_lng", sa.Numeric(precision=10, scale=7), nullable=True),
        sa.Column("photo_url", sa.String(length=500), nullable=True),
        sa.Column("quiz_answer", sa.String(length=200), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["quest_id"], ["quests.id"]),
        sa.ForeignKeyConstraint(["journey_id"], ["journeys.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "quest_id",
            name="uq_quest_progress_user_id_quest_id",
        ),
    )
    op.create_index("ix_quest_progress_user_status", "quest_progress", ["user_id", "status"])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_quest_progress_user_status", table_name="quest_progress")
    op.drop_table("quest_progress")
    op.drop_table("journey_quests")
    op.drop_index("ix_journeys_user_status", table_name="journeys")
    op.drop_table("journeys")
