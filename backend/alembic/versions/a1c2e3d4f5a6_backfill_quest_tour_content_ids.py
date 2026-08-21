"""quests.content_id 백필 — TourAPI 실시간 조회 연결 (KAN-102).

정적 퀘스트와 같은 매칭(backend/scripts/backfill_tour_content_ids.py)으로 얻은
client_key → contentId 스냅숏을 서버 quests에 채운다. 사진 인증 프롬프트 보강
(app/quests/verification.py)이 이 값을 쓴다. 이미 값이 있는 행은 덮지 않는다.

Revision ID: a1c2e3d4f5a6
Revises: e7f8a9b0c1d2
Create Date: 2026-08-21
"""

import json
from pathlib import Path

import sqlalchemy as sa

from alembic import op

revision = "a1c2e3d4f5a6"
down_revision = "e7f8a9b0c1d2"
branch_labels = None
depends_on = None

_MAPPING_PATH = Path(__file__).resolve().parents[1] / "data" / "kan102_tour_content_ids.json"


def upgrade() -> None:
    mapping: dict[str, dict[str, str]] = json.loads(_MAPPING_PATH.read_text(encoding="utf-8"))
    connection = op.get_bind()
    for client_key, ids in mapping.items():
        connection.execute(
            sa.text(
                "UPDATE quests SET content_id = :content_id, content_type_id = :content_type_id "
                "WHERE client_key = :client_key AND content_id IS NULL"
            ),
            {
                "content_id": ids["content_id"],
                "content_type_id": ids["content_type_id"],
                "client_key": client_key,
            },
        )


def downgrade() -> None:
    mapping: dict[str, dict[str, str]] = json.loads(_MAPPING_PATH.read_text(encoding="utf-8"))
    connection = op.get_bind()
    connection.execute(
        sa.text(
            "UPDATE quests SET content_id = NULL, content_type_id = NULL "
            "WHERE client_key = ANY(:keys)"
        ),
        {"keys": list(mapping.keys())},
    )
