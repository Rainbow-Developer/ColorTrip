from __future__ import annotations

from collections.abc import Callable
from datetime import timedelta
from pathlib import Path
from typing import Any
from uuid import uuid4

import pytest
import sqlalchemy as sa
from alembic.config import Config
from httpx import AsyncClient

from alembic import command
from app.core.base import now_kst
from app.core.database import engine
from tests.helpers import auth_headers, seed_quest_fixture

_ALEMBIC_INI = Path(__file__).resolve().parents[1] / "alembic.ini"


async def test_pr15_database_tables_and_enum_exist(client: AsyncClient) -> None:
    _ = client

    async with engine.connect() as connection:
        tables = await connection.run_sync(
            lambda sync_connection: set(sa.inspect(sync_connection).get_table_names())
        )
        dna_type_labels = await connection.run_sync(_dna_type_labels)

    assert {
        "quest_progress",
        "map_progress",
        "timeline_events",
        "trip_questions",
        "trip_question_options",
        "trip_replies",
        "user_dna_history",
        "user_consents",
    } <= tables
    assert dna_type_labels == ["nature", "food", "history", "activity", "healing"]


async def test_existing_tables_are_additively_preserved(client: AsyncClient) -> None:
    _ = client

    async with engine.connect() as connection:
        users_columns = await connection.run_sync(_columns_for("users"))
        refresh_indexes = await connection.run_sync(_indexes_for("refresh_tokens"))
        regions_columns = await connection.run_sync(_columns_for("regions"))
        quests_columns = await connection.run_sync(_columns_for("quests"))

    assert {
        "dna",
        "profile_image",
        "withdrawal_grace_until",
        "anonymized_at",
    } <= users_columns.keys()
    # 이메일 수집 폐지(c3d4e5f6a7b8)로 컬럼이 사라졌다.
    assert "email" not in users_columns
    assert refresh_indexes["ix_refresh_tokens_token_hash"]["unique"] is True
    assert {"center_lat", "center_lng"} <= regions_columns.keys()
    assert {"content_type_id", "lat", "lng", "verify_radius"} <= quests_columns.keys()


async def test_auth_migration_finishes_anonymizing_legacy_soft_deleted_users(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    _ = client
    # 이 테스트의 레거시 계정은 출시 전 테스트 계정이라는 마이그레이션 전제를 명시한다.
    monkeypatch.setenv("PRELAUNCH_CONSENT_MIGRATION_CONFIRMED", "true")
    user_id = uuid4()
    refresh_id = uuid4()
    overlap_user_id = uuid4()
    now = now_kst()

    async with engine.begin() as connection:
        await connection.run_sync(_downgrade_to_pre_consent_head)
        await connection.execute(
            sa.text(
                """
                INSERT INTO users (
                    social_provider, social_id, email, nickname, birth_date, dna,
                    profile_image, withdrawal_grace_until, anonymized_at, id,
                    created_at, updated_at, deleted_at
                ) VALUES (
                    'kakao', :social_id, :email, :nickname, :birth_date, :dna,
                    :profile_image, :withdrawal_grace_until, NULL, :id,
                    :created_at, :updated_at, :deleted_at
                )
                """
            ),
            {
                "social_id": "legacy-kakao-social-id",
                "email": "legacy@example.com",
                "nickname": "레거시 사용자",
                "birth_date": now.date() - timedelta(days=10_000),
                "dna": "nature",
                "profile_image": "https://example.com/profile.png",
                "withdrawal_grace_until": now + timedelta(days=7),
                "id": user_id,
                "created_at": now,
                "updated_at": now,
                "deleted_at": now,
            },
        )
        await connection.execute(
            sa.text(
                """
                INSERT INTO refresh_tokens (
                    user_id, token_hash, expires_at, id, created_at, updated_at, deleted_at
                ) VALUES (
                    :user_id, 'legacy-active-refresh', :expires_at, :id,
                    :created_at, :updated_at, NULL
                )
                """
            ),
            {
                "user_id": user_id,
                "expires_at": now + timedelta(days=14),
                "id": refresh_id,
                "created_at": now,
                "updated_at": now,
            },
        )

    async with engine.begin() as connection:
        await connection.run_sync(_upgrade_to_head)
        # head에서는 email 컬럼이 이미 삭제됐다(c3d4e5f6a7b8). 삽입 시점(be3e3c52de66)에는
        # 존재했으므로 legacy 값은 그대로 넣되, 여기서는 조회하지 않는다.
        legacy_user = (
            await connection.execute(
                sa.text(
                    """
                    SELECT social_id, withdrawal_grace_until, nickname, birth_date,
                           profile_image, dna, anonymized_at
                    FROM users
                    WHERE id = :id
                    """
                ),
                {"id": user_id},
            )
        ).one()
        refresh_deleted_at = await connection.scalar(
            sa.text("SELECT deleted_at FROM refresh_tokens WHERE id = :id"),
            {"id": refresh_id},
        )
        await connection.execute(
            sa.text(
                """
                INSERT INTO users (
                    social_provider, social_id, nickname, birth_date, dna,
                    profile_image, withdrawal_grace_until, anonymized_at, id,
                    created_at, updated_at, deleted_at
                ) VALUES (
                    'kakao', 'deployment-overlap-social-id',
                    '배포 중 사용자', :birth_date, 'food',
                    'https://example.com/overlap.png', NULL, NULL, :id,
                    :created_at, :updated_at, NULL
                )
                """
            ),
            {
                "birth_date": now.date() - timedelta(days=9_000),
                "id": overlap_user_id,
                "created_at": now,
                "updated_at": now,
            },
        )
        # Simulate the old API's seven-day withdrawal write while the new
        # migration has completed but the old container is still serving.
        await connection.execute(
            sa.text(
                """
                UPDATE users
                SET deleted_at = :deleted_at,
                    withdrawal_grace_until = :withdrawal_grace_until
                WHERE id = :id
                """
            ),
            {
                "deleted_at": now,
                "withdrawal_grace_until": now + timedelta(days=7),
                "id": overlap_user_id,
            },
        )
        overlap_user = (
            await connection.execute(
                sa.text(
                    """
                    SELECT social_id, withdrawal_grace_until, nickname, birth_date,
                           profile_image, dna, anonymized_at
                    FROM users
                    WHERE id = :id
                    """
                ),
                {"id": overlap_user_id},
            )
        ).one()

    assert legacy_user.social_id == f"deleted:{user_id}"
    assert legacy_user.withdrawal_grace_until is None
    assert legacy_user.nickname is None
    assert legacy_user.birth_date is None
    assert legacy_user.profile_image is None
    assert legacy_user.dna is None
    assert legacy_user.anonymized_at is not None
    assert refresh_deleted_at is not None
    assert overlap_user.social_id == f"deleted:{overlap_user_id}"
    assert overlap_user.withdrawal_grace_until is None
    assert overlap_user.nickname is None
    assert overlap_user.birth_date is None
    assert overlap_user.profile_image is None
    assert overlap_user.dna is None
    assert overlap_user.anonymized_at is not None

    async with engine.begin() as connection:
        await connection.run_sync(_downgrade_to_pre_consent_head)
        tables_after_downgrade = await connection.run_sync(
            lambda sync_connection: set(sa.inspect(sync_connection).get_table_names())
        )
        downgraded_user = (
            await connection.execute(
                sa.text(
                    """
                    SELECT social_id, nickname, birth_date, profile_image, dna
                    FROM users
                    WHERE id = :id
                    """
                ),
                {"id": user_id},
            )
        ).one()
        await connection.run_sync(_upgrade_to_head)

    assert "user_consents" not in tables_after_downgrade
    assert downgraded_user.social_id == f"deleted:{user_id}"
    assert downgraded_user.nickname is None
    assert downgraded_user.birth_date is None
    assert downgraded_user.profile_image is None
    assert downgraded_user.dna is None


async def test_new_tables_have_required_constraints(client: AsyncClient) -> None:
    _ = client

    async with engine.connect() as connection:
        quest_progress_uniques = await connection.run_sync(
            _unique_constraints_for("quest_progress")
        )
        map_progress_uniques = await connection.run_sync(_unique_constraints_for("map_progress"))
        timeline_fks = await connection.run_sync(_foreign_keys_for("timeline_events"))
        trip_replies_fks = await connection.run_sync(_foreign_keys_for("trip_replies"))
        dna_history_fks = await connection.run_sync(_foreign_keys_for("user_dna_history"))
        consent_uniques = await connection.run_sync(_unique_constraints_for("user_consents"))
        consent_indexes = await connection.run_sync(_indexes_for("user_consents"))
        consent_columns = await connection.run_sync(_columns_for("user_consents"))

    assert ("user_id", "quest_id") in quest_progress_uniques
    assert ("user_id", "region_id") in map_progress_uniques
    assert timeline_fks["quest_progress_id"] == ("quest_progress", ("id",), "SET NULL")
    assert trip_replies_fks["question_id"] == ("trip_questions", ("id",), None)
    assert trip_replies_fks["question_option_id"] == ("trip_question_options", ("id",), None)
    assert dna_history_fks["user_id"] == ("users", ("id",), None)
    assert ("user_id", "consent_type", "version") in consent_uniques
    assert consent_indexes["ix_user_consents_user_id"]["columns"] == ("user_id",)
    assert "deleted_at" not in consent_columns


async def test_journey_migration_schema_is_preserved(client: AsyncClient) -> None:
    _ = client

    async with engine.connect() as connection:
        tables = await connection.run_sync(
            lambda sync_connection: set(sa.inspect(sync_connection).get_table_names())
        )
        journeys_columns = await connection.run_sync(_columns_for("journeys"))
        journey_quests_uniques = await connection.run_sync(
            _unique_constraints_for("journey_quests")
        )
        quest_progress_uniques = await connection.run_sync(
            _unique_constraints_for("quest_progress")
        )
        journey_quests_fks = await connection.run_sync(_foreign_keys_for("journey_quests"))
        quest_progress_columns = await connection.run_sync(_columns_for("quest_progress"))
        quest_progress_fks = await connection.run_sync(_foreign_keys_for("quest_progress"))
        journeys_indexes = await connection.run_sync(_indexes_for("journeys"))
        journeys_fks = await connection.run_sync(_foreign_keys_for("journeys"))
        quest_progress_indexes = await connection.run_sync(_indexes_for("quest_progress"))

    assert {"journeys", "journey_quests"} <= tables
    assert {
        "user_id",
        "region_id",
        "title",
        "status",
        "completed_at",
    } <= journeys_columns.keys()
    assert journey_quests_uniques >= {("journey_id", "quest_id")}
    assert quest_progress_uniques >= {("user_id", "quest_id")}
    assert journey_quests_fks["journey_id"] == ("journeys", ("id",), None)
    assert journey_quests_fks["quest_id"] == ("quests", ("id",), None)
    assert {"journey_id", "quiz_answer"} <= quest_progress_columns.keys()
    assert quest_progress_columns["journey_id"]["nullable"] is True
    assert quest_progress_fks["journey_id"] == ("journeys", ("id",), None)
    assert journeys_fks["user_id"] == ("users", ("id",), None)
    assert journeys_fks["region_id"] == ("regions", ("id",), None)
    assert journeys_indexes["ix_journeys_user_status"] == {
        "columns": ("user_id", "status"),
        "unique": False,
    }
    assert quest_progress_indexes["ix_quest_progress_user_status"] == {
        "columns": ("user_id", "status"),
        "unique": False,
    }


async def test_domain_state_persistence_contract_has_stable_keys_and_idempotency(
    client: AsyncClient,
) -> None:
    _ = client

    async with engine.connect() as connection:
        regions_columns = await connection.run_sync(_columns_for("regions"))
        regions_uniques = await connection.run_sync(_unique_constraints_for("regions"))
        quests_columns = await connection.run_sync(_columns_for("quests"))
        quests_uniques = await connection.run_sync(_unique_constraints_for("quests"))
        journeys_columns = await connection.run_sync(_columns_for("journeys"))
        journeys_uniques = await connection.run_sync(_unique_constraints_for("journeys"))
        timeline_uniques = await connection.run_sync(_unique_constraints_for("timelines"))

    assert "slug" in regions_columns
    assert ("slug",) in regions_uniques
    assert "client_key" in quests_columns
    assert ("client_key",) in quests_uniques
    assert "client_request_id" in journeys_columns
    assert ("user_id", "client_request_id") in journeys_uniques
    assert ("quest_progress_id", "event_type") in timeline_uniques


async def test_domain_catalog_snapshot_is_seeded_by_migration(client: AsyncClient) -> None:
    _ = client

    async with engine.connect() as connection:
        region_count = await connection.scalar(
            sa.text("SELECT count(*) FROM regions WHERE slug IS NOT NULL")
        )
        quest_count = await connection.scalar(
            sa.text("SELECT count(*) FROM quests WHERE client_key IS NOT NULL")
        )
        gps_without_coordinates = await connection.scalar(
            sa.text(
                """
                SELECT count(*)
                FROM quests
                WHERE client_key IS NOT NULL
                  AND mission_type = 'gps'
                  AND (lat IS NULL OR lng IS NULL)
                """
            )
        )

    assert region_count == 11
    assert quest_count == 220
    assert gps_without_coordinates == 0


async def test_domain_catalog_migration_reuses_matching_legacy_rows(
    client: AsyncClient,
) -> None:
    _ = client
    region_id = uuid4()
    quest_id = uuid4()
    now = now_kst()

    async with engine.begin() as connection:
        await connection.run_sync(_downgrade_to_pre_domain_catalog_head)
        await connection.execute(sa.text("DELETE FROM quests"))
        await connection.execute(sa.text("DELETE FROM regions"))
        await connection.execute(
            sa.text(
                """
                INSERT INTO regions (
                    name, area_code, center_lat, center_lng,
                    id, created_at, updated_at, deleted_at
                ) VALUES (
                    '단양군', '2', NULL, NULL,
                    :id, :now, :now, NULL
                )
                """
            ),
            {"id": region_id, "now": now},
        )
        await connection.execute(
            sa.text(
                """
                INSERT INTO quests (
                    region_id, title, description, category, mission_type,
                    mission_meta, content_id, content_type_id, lat, lng,
                    verify_radius, thumbnail_url, id, created_at, updated_at, deleted_at
                ) VALUES (
                    :region_id, '소백산 연화봉 전망대 인증', NULL, 'nature', 'gps_photo',
                    NULL, NULL, NULL, NULL, NULL,
                    200, NULL, :id, :now, :now, NULL
                )
                """
            ),
            {"region_id": region_id, "id": quest_id, "now": now},
        )
        await connection.run_sync(_upgrade_to_head)

        migrated_region = (
            await connection.execute(sa.text("SELECT id, slug FROM regions WHERE name = '단양군'"))
        ).one()
        migrated_quest = (
            await connection.execute(
                sa.text(
                    "SELECT id, client_key FROM quests WHERE title = '소백산 연화봉 전망대 인증'"
                )
            )
        ).one()
        region_count = await connection.scalar(
            sa.text("SELECT count(*) FROM regions WHERE slug IS NOT NULL")
        )
        quest_count = await connection.scalar(
            sa.text("SELECT count(*) FROM quests WHERE client_key IS NOT NULL")
        )

    assert migrated_region == (region_id, "danyang")
    assert migrated_quest == (quest_id, "dy1")
    assert region_count == 11
    assert quest_count == 220


async def test_domain_catalog_migration_deduplicates_legacy_timeline_events(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    # 이 테스트도 기존 테스트 계정을 가진 상태에서 head로 복귀하므로 승인 전제를 명시한다.
    monkeypatch.setenv("PRELAUNCH_CONSENT_MIGRATION_CONFIRMED", "true")
    seed = await seed_quest_fixture()
    headers = await auth_headers(client)
    verified = await client.post(
        f"/api/v1/quests/{seed['photo_quest_id']}/verify",
        json={"photo_url": "/uploads/photos/legacy.jpg"},
        headers=headers,
    )
    assert verified.status_code == 200

    async with engine.begin() as connection:
        await connection.run_sync(_downgrade_to_pre_domain_catalog_head)
        original = (
            await connection.execute(
                sa.text(
                    """
                    SELECT user_id, region_id, quest_progress_id, event_type,
                           title, occurred_at, created_at, updated_at
                    FROM timelines
                    WHERE quest_progress_id IS NOT NULL
                      AND event_type = 'quest_completed'
                    """
                )
            )
        ).one()
        await connection.execute(
            sa.text(
                """
                INSERT INTO timelines (
                    id, user_id, region_id, quest_progress_id, event_type,
                    title, occurred_at, created_at, updated_at, deleted_at
                ) VALUES (
                    :id, :user_id, :region_id, :quest_progress_id, :event_type,
                    :title, :occurred_at, :created_at, :updated_at, NULL
                )
                """
            ),
            {
                "id": uuid4(),
                "user_id": original.user_id,
                "region_id": original.region_id,
                "quest_progress_id": original.quest_progress_id,
                "event_type": original.event_type,
                "title": original.title,
                "occurred_at": original.occurred_at,
                "created_at": original.created_at,
                "updated_at": original.updated_at,
            },
        )

        await connection.run_sync(_upgrade_to_head)
        remaining = await connection.scalar(
            sa.text(
                """
                SELECT count(*)
                FROM timelines
                WHERE quest_progress_id = :quest_progress_id
                  AND event_type = 'quest_completed'
                """
            ),
            {"quest_progress_id": original.quest_progress_id},
        )

    assert remaining == 1


async def test_new_tables_have_database_defaults_and_sort_indexes(
    client: AsyncClient,
) -> None:
    _ = client

    async with engine.connect() as connection:
        quest_progress_status_default = await connection.run_sync(
            _column_default_for("quest_progress", "status")
        )
        map_progress_completed_count_default = await connection.run_sync(
            _column_default_for("map_progress", "completed_count")
        )
        timeline_index = await connection.run_sync(
            _index_definition_for("ix_timeline_events_user_occurred")
        )
        trip_replies_index = await connection.run_sync(
            _index_definition_for("ix_trip_replies_user_created")
        )
        dna_history_index = await connection.run_sync(
            _index_definition_for("ix_user_dna_history_user_created")
        )

    assert quest_progress_status_default is not None
    assert "in_progress" in quest_progress_status_default
    assert map_progress_completed_count_default == "0"
    assert "occurred_at DESC" in timeline_index
    assert "created_at DESC" in trip_replies_index
    assert "created_at DESC" in dna_history_index


async def test_new_models_insert_with_application_defaults(client: AsyncClient) -> None:
    _ = client

    from app.auth.models import User
    from app.core.base import now_kst
    from app.core.database import AsyncSessionLocal
    from app.progress.models import MapProgress
    from app.quests.models import Quest, QuestProgress
    from app.regions.models import Region
    from app.timeline.models import TimelineEvent
    from app.trip_dna.models import (
        TripQuestion,
        TripQuestionOption,
        TripReply,
        UserDnaHistory,
    )

    async with AsyncSessionLocal() as session:
        user = User(social_provider="kakao", social_id="schema-default-user")
        region = Region(name="테스트군", area_code="schema-region")
        session.add_all([user, region])
        await session.flush()

        quest = Quest(
            region_id=region.id,
            title="기본값 검증 퀘스트",
            category="nature",
        )
        session.add(quest)
        await session.flush()

        quest_progress = QuestProgress(user_id=user.id, quest_id=quest.id)
        map_progress = MapProgress(user_id=user.id, region_id=region.id)
        session.add_all([quest_progress, map_progress])
        await session.flush()

        timeline_event = TimelineEvent(
            user_id=user.id,
            quest_progress_id=quest_progress.id,
            event_type="quest_completed",
            occurred_at=now_kst(),
        )
        question = TripQuestion(question="어떤 여행을 선호하나요?")
        session.add_all([timeline_event, question])
        await session.flush()

        option = TripQuestionOption(
            question_id=question.id,
            content="숲길 산책",
            category="nature",
        )
        session.add(option)
        await session.flush()

        reply = TripReply(
            user_id=user.id,
            question_id=question.id,
            question_option_id=option.id,
        )
        dna_history = UserDnaHistory(user_id=user.id, dna="nature")
        session.add_all([reply, dna_history])
        await session.flush()

        assert quest.mission_type == "gps_photo"
        assert quest.verify_radius == 200
        assert quest_progress.status == "in_progress"
        assert map_progress.completed_count == 0
        assert timeline_event.occurred_at is not None
        assert option.score_value == {}
        assert reply.id is not None
        assert dna_history.id is not None


def _columns_for(table_name: str) -> Callable[[sa.Connection], dict[str, Any]]:
    def inspect_columns(connection: sa.Connection) -> dict[str, Any]:
        return {column["name"]: column for column in sa.inspect(connection).get_columns(table_name)}

    return inspect_columns


def _dna_type_labels(connection: sa.Connection) -> list[str]:
    return list(
        connection.execute(
            sa.text(
                """
                SELECT pg_enum.enumlabel
                FROM pg_enum
                JOIN pg_type ON pg_type.oid = pg_enum.enumtypid
                WHERE pg_type.typname = 'dna_type'
                ORDER BY pg_enum.enumsortorder
                """
            )
        ).scalars()
    )


def _column_default_for(
    table_name: str,
    column_name: str,
) -> Callable[[sa.Connection], str | None]:
    def inspect_column_default(connection: sa.Connection) -> str | None:
        return connection.execute(
            sa.text(
                """
                SELECT pg_get_expr(pg_attrdef.adbin, pg_attrdef.adrelid)
                FROM pg_attrdef
                JOIN pg_class ON pg_class.oid = pg_attrdef.adrelid
                JOIN pg_attribute
                    ON pg_attribute.attrelid = pg_class.oid
                   AND pg_attribute.attnum = pg_attrdef.adnum
                WHERE pg_class.relname = :table_name
                  AND pg_attribute.attname = :column_name
                """
            ),
            {"table_name": table_name, "column_name": column_name},
        ).scalar_one_or_none()

    return inspect_column_default


def _index_definition_for(index_name: str) -> Callable[[sa.Connection], str]:
    def inspect_index_definition(connection: sa.Connection) -> str:
        return str(
            connection.execute(
                sa.text(
                    """
                    SELECT pg_get_indexdef(pg_class.oid)
                    FROM pg_class
                    WHERE pg_class.relname = :index_name
                    """
                ),
                {"index_name": index_name},
            ).scalar_one()
        )

    return inspect_index_definition


def _indexes_for(table_name: str) -> Callable[[sa.Connection], dict[str, dict[str, Any]]]:
    def inspect_indexes(connection: sa.Connection) -> dict[str, dict[str, Any]]:
        indexes: dict[str, dict[str, Any]] = {}
        for index in sa.inspect(connection).get_indexes(table_name):
            name = index["name"]
            if name is None:
                continue
            indexes[name] = {
                "columns": tuple(index["column_names"]),
                "unique": index["unique"],
            }
        return indexes

    return inspect_indexes


def _unique_constraints_for(table_name: str) -> Callable[[sa.Connection], set[tuple[str, ...]]]:
    def inspect_uniques(connection: sa.Connection) -> set[tuple[str, ...]]:
        return {
            tuple(constraint["column_names"])
            for constraint in sa.inspect(connection).get_unique_constraints(table_name)
        }

    return inspect_uniques


def _foreign_keys_for(
    table_name: str,
) -> Callable[[sa.Connection], dict[str, tuple[str, tuple[str, ...], str | None]]]:
    def inspect_foreign_keys(
        connection: sa.Connection,
    ) -> dict[str, tuple[str, tuple[str, ...], str | None]]:
        return {
            foreign_key["constrained_columns"][0]: (
                foreign_key["referred_table"],
                tuple(foreign_key["referred_columns"]),
                (foreign_key.get("options") or {}).get("ondelete"),
            )
            for foreign_key in sa.inspect(connection).get_foreign_keys(table_name)
        }

    return inspect_foreign_keys


def _downgrade_to_pre_consent_head(connection: sa.Connection) -> None:
    command.downgrade(_alembic_config(connection), "be3e3c52de66")


def _upgrade_to_head(connection: sa.Connection) -> None:
    command.upgrade(_alembic_config(connection), "head")


def _alembic_config(connection: sa.Connection) -> Config:
    config = Config(str(_ALEMBIC_INI))
    config.attributes["connection"] = connection
    return config


def _downgrade_to_pre_domain_catalog_head(connection: sa.Connection) -> None:
    command.downgrade(_alembic_config(connection), "7f2a1c9d4e6b")
