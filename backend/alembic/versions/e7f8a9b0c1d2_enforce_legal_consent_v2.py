"""enforce v2 consent evidence after compatible rollout.

Run this revision only after all API instances understand document_digest and
source.  This makes the destructive constraint change safe during a rolling
deployment.
"""

from collections.abc import Sequence
import os

import sqlalchemy as sa
from alembic import op

revision: str = "e7f8a9b0c1d2"
down_revision: str | Sequence[str] | None = "d6e7f8a9b0c1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    connection = op.get_bind()
    existing_users = connection.execute(sa.text("SELECT count(*) FROM users")).scalar_one()
    if existing_users and os.getenv("PRELAUNCH_CONSENT_ENFORCEMENT_CONFIRMED") != "true":
        raise RuntimeError(
            "Existing accounts found. Deploy compatible API instances first, then set "
            "PRELAUNCH_CONSENT_ENFORCEMENT_CONFIRMED=true before enforcing v2 consents."
        )
    op.execute(sa.text("DELETE FROM user_consents WHERE consent_type = 'marketing'"))
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
    op.alter_column("user_consents", "source", nullable=True)
    op.alter_column("user_consents", "document_digest", nullable=True)
