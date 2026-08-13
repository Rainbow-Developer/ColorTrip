"""align quests.mission_type with the QR quests shipped in the app

FE 정적 데이터(frontend/lib/data/static/quests_data.dart)는 지역당 1개씩 11개 퀘스트를
verify: 'qr'로 노출하는데, DB 카탈로그(KAN-55 스냅샷)는 이들을 mission_type='photo'로
가지고 있었다. 그래서 앱이 QR 스캐너를 띄우고 qr_payload만 보내면 서버가 photo_url을
요구하며 400으로 떨어져 **QR 인증이 한 번도 성공할 수 없었다**(KAN-75).

정적 데이터를 SOT로 삼아 이 11개의 mission_type을 'qr'로 맞춘다. 이미 'qr'이거나 다른
타입으로 운영자가 손댄 행은 건드리지 않는다(photo인 것만 바꾼다).

Revision ID: c1a7e5d90b42
Revises: b2c3d4e5f6a7
Create Date: 2026-08-13
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "c1a7e5d90b42"
down_revision: str | Sequence[str] | None = "b2c3d4e5f6a7"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# frontend/lib/data/static/quests_data.dart 의 verify: 'qr' 퀘스트 (시·군당 1개).
# 값을 바꾸면 현장 인쇄 QR(client_key로 서명)과 어긋나므로 정적 데이터와 함께 옮길 것.
_QR_CLIENT_KEYS = (
    "dy3",
    "cj3",
    "be5",
    "cu4",
    "jc5",
    "es4",
    "jh4",
    "jp4",
    "gs4",
    "oc4",
    "yd1",
)


def upgrade() -> None:
    op.get_bind().execute(
        sa.text(
            "UPDATE quests SET mission_type = 'qr', updated_at = NOW() "
            "WHERE client_key = ANY(:keys) AND mission_type = 'photo'"
        ),
        {"keys": list(_QR_CLIENT_KEYS)},
    )


def downgrade() -> None:
    op.get_bind().execute(
        sa.text(
            "UPDATE quests SET mission_type = 'photo', updated_at = NOW() "
            "WHERE client_key = ANY(:keys) AND mission_type = 'qr'"
        ),
        {"keys": list(_QR_CLIENT_KEYS)},
    )
