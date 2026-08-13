from pathlib import Path

from alembic.config import Config
from alembic.script import ScriptDirectory


def test_alembic_revision_graph_has_exactly_one_head() -> None:
    config_path = Path(__file__).resolve().parents[1] / "alembic.ini"
    script = ScriptDirectory.from_config(Config(str(config_path)))
    heads = script.get_heads()

    assert heads == ["e8c3a91d7f04"], f"Expected Alembic head e8c3a91d7f04, found: {heads}"
