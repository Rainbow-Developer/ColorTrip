"""add journey start and end dates

Revision ID: c9d4e7a2b8f3
Revises: 9c0244355f03
Create Date: 2026-07-16

여행 생성 시 이름(title)과 함께 여행 기간(start_date·end_date)을 받도록
journeys에 DATE 컬럼 2개를 추가한다 (docs/specs/010-journey/description.md).
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c9d4e7a2b8f3"
down_revision: str | Sequence[str] | None = "9c0244355f03"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("journeys", sa.Column("start_date", sa.Date(), nullable=True))
    op.add_column("journeys", sa.Column("end_date", sa.Date(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("journeys", "end_date")
    op.drop_column("journeys", "start_date")
