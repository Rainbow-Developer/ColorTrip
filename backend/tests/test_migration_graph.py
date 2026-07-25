from alembic.config import Config
from alembic.script import ScriptDirectory


def test_alembic_revision_graph_has_exactly_one_head() -> None:
    script = ScriptDirectory.from_config(Config("alembic.ini"))
    heads = script.get_heads()

    assert len(heads) == 1, f"Expected exactly one Alembic head, found: {heads}"
