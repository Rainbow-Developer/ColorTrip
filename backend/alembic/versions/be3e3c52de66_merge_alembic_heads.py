"""merge alembic heads

Revision ID: be3e3c52de66
Revises: 5eab7d8363e0, c9d4e7a2b8f3
Create Date: 2026-07-25 13:56:11.223790

"""
from collections.abc import Sequence


# revision identifiers, used by Alembic.
revision: str = "be3e3c52de66"
down_revision: str | Sequence[str] | None = ("5eab7d8363e0", "c9d4e7a2b8f3")
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
