from pathlib import Path

from alembic.config import Config
from alembic.script import ScriptDirectory


def test_alembic_revision_graph_has_exactly_one_head() -> None:
    config_path = Path(__file__).resolve().parents[1] / "alembic.ini"
    script = ScriptDirectory.from_config(Config(str(config_path)))
    heads = script.get_heads()

    assert heads == ["b2c3d4e5f6a7"], f"Expected Alembic head b2c3d4e5f6a7, found: {heads}"
