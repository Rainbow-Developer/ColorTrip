"""clear stored verification coordinates for gps quests

위치 인증은 좌표를 서버로 보내지 않는 설계(B안 — docs/specs/050-quest-verification/
location-law-review.md)인데, `a3df7fc`(KAN-55) 이후 FE가 좌표를 전송했고 서버가
`quest_progress.verified_lat/verified_lng`에 **저장까지** 하고 있었다. KAN-77에서
전송·수신 경로를 막았으므로, 그동안 쌓인 좌표도 함께 지운다.

gps 미션만 대상으로 한다 — gps_photo 서버 검증 경로는 FE가 사용한 적이 없고,
쓰게 되는 시점은 위치기반서비스사업 신고 이후다.

되돌릴 수 없다(downgrade는 no-op). 개인위치정보를 복원하는 downgrade는 만들지 않는다.

Revision ID: e8c3a91d7f04
Revises: c1a7e5d90b42
Create Date: 2026-08-14
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "e8c3a91d7f04"
down_revision: str | Sequence[str] | None = "c1a7e5d90b42"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.get_bind().execute(
        sa.text(
            """
            UPDATE quest_progress
            SET verified_lat = NULL, verified_lng = NULL, updated_at = NOW()
            WHERE (verified_lat IS NOT NULL OR verified_lng IS NOT NULL)
              AND quest_id IN (SELECT id FROM quests WHERE mission_type = 'gps')
            """
        )
    )


def downgrade() -> None:
    """복원하지 않는다 — 지운 좌표는 개인위치정보이고 되살릴 이유가 없다."""
