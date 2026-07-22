from __future__ import annotations

from collections.abc import Callable
from typing import Any

import sqlalchemy as sa
from httpx import AsyncClient

from app.core.database import engine


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
    assert refresh_indexes["ix_refresh_tokens_token_hash"]["unique"] is True
    assert {"center_lat", "center_lng"} <= regions_columns.keys()
    assert {"content_type_id", "lat", "lng", "verify_radius"} <= quests_columns.keys()


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

    assert ("user_id", "quest_id") in quest_progress_uniques
    assert ("user_id", "region_id") in map_progress_uniques
    assert timeline_fks["quest_progress_id"] == ("quest_progress", ("id",), "SET NULL")
    assert trip_replies_fks["question_id"] == ("trip_questions", ("id",), None)
    assert trip_replies_fks["question_option_id"] == ("trip_question_options", ("id",), None)
    assert dna_history_fks["user_id"] == ("users", ("id",), None)


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
