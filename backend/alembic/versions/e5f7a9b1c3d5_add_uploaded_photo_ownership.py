"""add uploaded photo ownership

Revision ID: e5f7a9b1c3d5
Revises: d4e8f6a1b2c3
Create Date: 2026-08-01
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "e5f7a9b1c3d5"
down_revision: str | Sequence[str] | None = "d4e8f6a1b2c3"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "uploaded_photos",
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("photo_url", sa.String(length=500), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "photo_url", name="uq_uploaded_photos_user_url"),
    )
    op.create_index("ix_uploaded_photos_user_url", "uploaded_photos", ["user_id", "photo_url"])


def downgrade() -> None:
    op.drop_index("ix_uploaded_photos_user_url", table_name="uploaded_photos")
    op.drop_table("uploaded_photos")
