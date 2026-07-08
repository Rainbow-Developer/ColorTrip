"""add pr15 database spec tables

Revision ID: a4f2c8d1e9b0
Revises: f4b2a9c67e18
Create Date: 2026-07-08 00:00:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a4f2c8d1e9b0"
down_revision: str | Sequence[str] | None = "f4b2a9c67e18"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

DNA_TYPE_VALUES = ("nature", "food", "history", "activity", "healing")


def _dna_type(create_type: bool = False) -> postgresql.ENUM:
    return postgresql.ENUM(*DNA_TYPE_VALUES, name="dna_type", create_type=create_type)


def upgrade() -> None:
    """Upgrade schema."""
    _dna_type(create_type=True).create(op.get_bind(), checkfirst=True)

    op.add_column("users", sa.Column("dna", _dna_type(), nullable=True))
    op.add_column("users", sa.Column("profile_image", sa.String(length=500), nullable=True))

    op.alter_column(
        "quest_progress",
        "status",
        existing_type=sa.String(length=20),
        server_default="in_progress",
    )
    op.create_check_constraint(
        "ck_quest_progress_status",
        "quest_progress",
        "status IN ('in_progress', 'completed')",
    )

    op.create_table(
        "map_progress",
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("region_id", sa.UUID(), nullable=False),
        sa.Column("completed_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("first_colored_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["region_id"], ["regions.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "region_id", name="uq_map_progress_user_region"),
    )
    op.create_index("ix_map_progress_region_id", "map_progress", ["region_id"])
    op.create_index("ix_map_progress_user_id", "map_progress", ["user_id"])

    op.create_table(
        "timeline_events",
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("quest_progress_id", sa.UUID(), nullable=True),
        sa.Column("event_type", sa.String(length=30), nullable=False),
        sa.Column("title", sa.String(length=100), nullable=True),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["quest_progress_id"], ["quest_progress.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_timeline_events_user_occurred",
        "timeline_events",
        ["user_id", sa.text("occurred_at DESC")],
    )

    op.create_table(
        "trip_questions",
        sa.Column("question", sa.Text(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=True),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "trip_question_options",
        sa.Column("question_id", sa.UUID(), nullable=False),
        sa.Column("score_value", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("category", _dna_type(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=True),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["question_id"], ["trip_questions.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_trip_question_options_question_id",
        "trip_question_options",
        ["question_id"],
    )

    op.create_table(
        "trip_replies",
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("question_id", sa.UUID(), nullable=False),
        sa.Column("question_option_id", sa.UUID(), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["question_id"], ["trip_questions.id"]),
        sa.ForeignKeyConstraint(["question_option_id"], ["trip_question_options.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_trip_replies_user_created",
        "trip_replies",
        ["user_id", sa.text("created_at DESC")],
    )
    op.create_index("ix_trip_replies_user_id", "trip_replies", ["user_id"])

    op.create_table(
        "user_dna_history",
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("dna", _dna_type(), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_user_dna_history_user_created",
        "user_dna_history",
        ["user_id", sa.text("created_at DESC")],
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_user_dna_history_user_created", table_name="user_dna_history")
    op.drop_table("user_dna_history")

    op.drop_index("ix_trip_replies_user_id", table_name="trip_replies")
    op.drop_index("ix_trip_replies_user_created", table_name="trip_replies")
    op.drop_table("trip_replies")

    op.drop_index(
        "ix_trip_question_options_question_id",
        table_name="trip_question_options",
    )
    op.drop_table("trip_question_options")
    op.drop_table("trip_questions")

    op.drop_index("ix_timeline_events_user_occurred", table_name="timeline_events")
    op.drop_table("timeline_events")

    op.drop_index("ix_map_progress_user_id", table_name="map_progress")
    op.drop_index("ix_map_progress_region_id", table_name="map_progress")
    op.drop_table("map_progress")

    op.drop_constraint("ck_quest_progress_status", "quest_progress", type_="check")
    op.alter_column(
        "quest_progress",
        "status",
        existing_type=sa.String(length=20),
        server_default=None,
    )

    op.drop_column("users", "profile_image")
    op.drop_column("users", "dna")
    _dna_type().drop(op.get_bind(), checkfirst=True)
