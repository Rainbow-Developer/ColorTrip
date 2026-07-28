from pathlib import Path

from alembic.config import Config
from alembic.script import ScriptDirectory


def test_alembic_revision_graph_has_exactly_one_head() -> None:
    config_path = Path(__file__).resolve().parents[1] / "alembic.ini"
    script = ScriptDirectory.from_config(Config(str(config_path)))
    heads = script.get_heads()

    assert heads == ["7f2a1c9d4e6b"], f"Expected Alembic head 7f2a1c9d4e6b, found: {heads}"
