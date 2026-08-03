from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DART_CATALOG = REPOSITORY_ROOT / "frontend/lib/data/static/quests_data.dart"
SERVER_SNAPSHOT = REPOSITORY_ROOT / "backend/alembic/data/kan55_domain_catalog_snapshot.json"


def _dart_quest_contracts() -> dict[str, tuple[str, str]]:
    source = DART_CATALOG.read_text(encoding="utf-8")
    contracts: dict[str, tuple[str, str]] = {}
    for block in re.findall(r"\bQuest\((.*?)\n  \),", source, flags=re.DOTALL):
        quest_id = re.search(r"\bid: '([^']+)'", block)
        region = re.search(r"\bregion: '([^']+)'", block)
        verification = re.search(r"\bverify: '([^']+)'", block)
        assert quest_id and region and verification
        contracts[quest_id.group(1)] = (region.group(1), verification.group(1))
    return contracts


def _server_snapshot() -> list[dict[str, Any]]:
    return json.loads(SERVER_SNAPSHOT.read_text(encoding="utf-8"))


def test_server_snapshot_matches_all_flutter_quest_keys() -> None:
    dart_contracts = _dart_quest_contracts()
    snapshot = _server_snapshot()
    snapshot_contracts = {
        row["client_key"]: (row["region_slug"], row["mission_type"]) for row in snapshot
    }

    assert len(dart_contracts) == 220
    assert len(snapshot_contracts) == 220
    assert snapshot_contracts == dart_contracts


def test_server_snapshot_has_verified_coordinates_for_every_gps_quest() -> None:
    gps_rows = [row for row in _server_snapshot() if row["mission_type"] == "gps"]

    assert len(gps_rows) == 28
    assert all(row["lat"] is not None and row["lng"] is not None for row in gps_rows)
