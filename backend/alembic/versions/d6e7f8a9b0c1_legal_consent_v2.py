"""record v2 consent evidence and remove marketing consent.

Revision ID: d6e7f8a9b0c1
Revises: c3d4e5f6a7b8
Create Date: 2026-08-15
"""

from collections.abc import Sequence
import os

import sqlalchemy as sa
from alembic import op

revision: str = "d6e7f8a9b0c1"
down_revision: str | Sequence[str] | None = "c3d4e5f6a7b8"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TERMS_DIGEST = "f5522ec86cee565890ba32ee052ff59cdfc8fff149f45b6ef0a382b5b1c3d610"
PRIVACY_DIGEST = "82ec37f76387b5848bca9ccd757d6dc747e748eb312079d9f613aa216b304747"


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
    op.execute(sa.text("DELETE FROM user_consents WHERE consent_type = 'marketing'"))
    connection.execute(
        sa.text(
            "UPDATE user_consents SET version = 'terms-v2', agreed = true, "
            "document_digest = :digest, source = 'prelaunch_migration' "
            "WHERE consent_type = 'terms'"
        ),
        {"digest": TERMS_DIGEST},
    )
    connection.execute(
        sa.text(
            "UPDATE user_consents SET version = 'privacy-v2', agreed = true, "
            "document_digest = :digest, source = 'prelaunch_migration' "
            "WHERE consent_type = 'privacy'"
        ),
        {"digest": PRIVACY_DIGEST},
    )
    op.alter_column("user_consents", "document_digest", nullable=False)
    op.alter_column("user_consents", "source", nullable=False)
    op.drop_constraint("ck_user_consents_type", "user_consents", type_="check")
    op.create_check_constraint(
        "ck_user_consents_type", "user_consents", "consent_type IN ('terms', 'privacy')"
    )


def downgrade() -> None:
    op.drop_constraint("ck_user_consents_type", "user_consents", type_="check")
    op.create_check_constraint(
        "ck_user_consents_type",
        "user_consents",
        "consent_type IN ('terms', 'privacy', 'marketing')",
    )
    op.drop_column("user_consents", "source")
    op.drop_column("user_consents", "document_digest")
