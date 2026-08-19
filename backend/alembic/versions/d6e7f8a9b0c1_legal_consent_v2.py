"""add v2 consent evidence columns compatibly.

Revision ID: d6e7f8a9b0c1
Revises: c3d4e5f6a7b8
Create Date: 2026-08-15
"""

from collections.abc import Sequence
import os

import sqlalchemy as sa
from alembic import op

from app.legal.documents import PRIVACY, TERMS

revision: str = "d6e7f8a9b0c1"
down_revision: str | Sequence[str] | None = "c3d4e5f6a7b8"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

def upgrade() -> None:
    connection = op.get_bind()
    existing_users = connection.execute(sa.text("SELECT count(*) FROM users")).scalar_one()
    if existing_users and os.getenv("PRELAUNCH_CONSENT_MIGRATION_CONFIRMED") != "true":
        raise RuntimeError(
            "Existing accounts found. Confirm all are prelaunch test accounts by setting "
            "PRELAUNCH_CONSENT_MIGRATION_CONFIRMED=true before upgrading."
        )

    op.add_column("user_consents", sa.Column("document_digest", sa.String(64), nullable=True))
    op.add_column("user_consents", sa.Column("source", sa.String(30), nullable=True))
    # Rolling deployment phase: old API containers can still insert marketing rows
    # and omit the new evidence columns until every instance is replaced.  The
    # follow-up revision performs the destructive enforcement step.
    connection.execute(
        sa.text(
            "UPDATE user_consents SET version = :version, agreed = true, "
            "document_digest = :digest, source = 'prelaunch_migration' "
            "WHERE consent_type = 'terms'"
        ),
        {"version": TERMS.version, "digest": TERMS.digest},
    )
    connection.execute(
        sa.text(
            "UPDATE user_consents SET version = :version, agreed = true, "
            "document_digest = :digest, source = 'prelaunch_migration' "
            "WHERE consent_type = 'privacy'"
        ),
        {"version": PRIVACY.version, "digest": PRIVACY.digest},
    )


def downgrade() -> None:
    op.drop_column("user_consents", "source")
    op.drop_column("user_consents", "document_digest")
