"""persist domain state contract

Revision ID: d4e8f6a1b2c3
Revises: 7f2a1c9d4e6b
Create Date: 2026-07-28
"""

import json
import uuid
from collections.abc import Sequence
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import sqlalchemy as sa

from alembic import op

revision: str = "d4e8f6a1b2c3"
down_revision: str | Sequence[str] | None = "7f2a1c9d4e6b"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_KST = ZoneInfo("Asia/Seoul")
_CATALOG_PATH = Path(__file__).resolve().parents[1] / "data" / "kan55_domain_catalog_snapshot.json"
_REGIONS = (
    ("cheongju", "청주시", "10"),
    ("chungju", "충주시", "11"),
    ("jecheon", "제천시", "7"),
    ("boeun", "보은군", "3"),
    ("okcheon", "옥천군", "5"),
    ("yeongdong", "영동군", "4"),
    ("jeungpyeong", "증평군", "12"),
    ("jincheon", "진천군", "8"),
    ("goesan", "괴산군", "1"),
    ("eumseong", "음성군", "6"),
    ("danyang", "단양군", "2"),
)


def upgrade() -> None:
    op.add_column("regions", sa.Column("slug", sa.String(length=30), nullable=True))
    op.create_unique_constraint("uq_regions_slug", "regions", ["slug"])

    op.add_column("quests", sa.Column("client_key", sa.String(length=30), nullable=True))
    op.create_unique_constraint("uq_quests_client_key", "quests", ["client_key"])

    op.add_column("journeys", sa.Column("client_request_id", sa.UUID(), nullable=True))
    op.create_unique_constraint(
        "uq_journeys_user_id_client_request_id",
        "journeys",
        ["user_id", "client_request_id"],
    )

    op.create_unique_constraint(
        "uq_timelines_quest_progress_id_event_type",
        "timelines",
        ["quest_progress_id", "event_type"],
    )
    _seed_domain_catalog()


def downgrade() -> None:
    op.drop_constraint(
        "uq_timelines_quest_progress_id_event_type",
        "timelines",
        type_="unique",
    )
    op.drop_constraint(
        "uq_journeys_user_id_client_request_id",
        "journeys",
        type_="unique",
    )
    op.drop_column("journeys", "client_request_id")
    op.drop_constraint("uq_quests_client_key", "quests", type_="unique")
    op.drop_column("quests", "client_key")
    op.drop_constraint("uq_regions_slug", "regions", type_="unique")
    op.drop_column("regions", "slug")


def _seed_domain_catalog() -> None:
    connection = op.get_bind()
    now = datetime.now(_KST)
    region_ids: dict[str, uuid.UUID] = {}

    for slug, name, area_code in _REGIONS:
        matches = (
            connection.execute(
                sa.text(
                    """
                SELECT id, slug
                FROM regions
                WHERE deleted_at IS NULL
                  AND (name = :name OR slug = :slug)
                ORDER BY id
                """
                ),
                {"name": name, "slug": slug},
            )
            .mappings()
            .all()
        )
        distinct_ids = {row["id"] for row in matches}
        if len(distinct_ids) > 1:
            raise RuntimeError(
                f"KAN-55 migration found ambiguous region rows for {slug!r}; "
                "resolve duplicates before retrying."
            )

        if matches:
            region_id = matches[0]["id"]
            if matches[0]["slug"] is None:
                connection.execute(
                    sa.text("UPDATE regions SET slug = :slug, updated_at = :now WHERE id = :id"),
                    {"slug": slug, "now": now, "id": region_id},
                )
        else:
            region_id = uuid.uuid5(uuid.NAMESPACE_URL, f"colortrip:region:{slug}")
            connection.execute(
                sa.text(
                    """
                    INSERT INTO regions (
                        id, name, slug, area_code, center_lat, center_lng,
                        created_at, updated_at, deleted_at
                    ) VALUES (
                        :id, :name, :slug, :area_code, NULL, NULL,
                        :now, :now, NULL
                    )
                    """
                ),
                {
                    "id": region_id,
                    "name": name,
                    "slug": slug,
                    "area_code": area_code,
                    "now": now,
                },
            )
        region_ids[slug] = region_id

    snapshot = json.loads(_CATALOG_PATH.read_text(encoding="utf-8"))
    for row in snapshot:
        client_key = row["client_key"]
        region_id = region_ids[row["region_slug"]]
        matches = (
            connection.execute(
                sa.text(
                    """
                SELECT id, region_id, client_key
                FROM quests
                WHERE deleted_at IS NULL
                  AND (client_key = :client_key OR (region_id = :region_id AND title = :title))
                ORDER BY id
                """
                ),
                {
                    "client_key": client_key,
                    "region_id": region_id,
                    "title": row["title"],
                },
            )
            .mappings()
            .all()
        )
        distinct_ids = {match["id"] for match in matches}
        if len(distinct_ids) > 1:
            raise RuntimeError(
                f"KAN-55 migration found ambiguous quest rows for {client_key!r}; "
                "resolve duplicates before retrying."
            )

        if matches:
            match = matches[0]
            if match["region_id"] != region_id:
                raise RuntimeError(
                    f"KAN-55 migration found client key {client_key!r} in another region."
                )
            if match["client_key"] is None:
                connection.execute(
                    sa.text(
                        "UPDATE quests "
                        "SET client_key = :client_key, updated_at = :now "
                        "WHERE id = :id"
                    ),
                    {
                        "client_key": client_key,
                        "now": now,
                        "id": match["id"],
                    },
                )
            continue

        connection.execute(
            sa.text(
                """
                INSERT INTO quests (
                    id, region_id, client_key, title, description, category,
                    mission_type, mission_meta, content_id, content_type_id,
                    lat, lng, verify_radius, thumbnail_url,
                    created_at, updated_at, deleted_at
                ) VALUES (
                    :id, :region_id, :client_key, :title, :description, :category,
                    :mission_type, CAST(:mission_meta AS jsonb), NULL, NULL,
                    :lat, :lng, :verify_radius, NULL,
                    :now, :now, NULL
                )
                """
            ),
            {
                "id": uuid.uuid5(uuid.NAMESPACE_URL, f"colortrip:quest:{client_key}"),
                "region_id": region_id,
                "client_key": client_key,
                "title": row["title"],
                "description": row["description"],
                "category": row["category"],
                "mission_type": row["mission_type"],
                "mission_meta": json.dumps(row["mission_meta"], ensure_ascii=False),
                "lat": row["lat"],
                "lng": row["lng"],
                "verify_radius": row["verify_radius"],
                "now": now,
            },
        )
