"""add user consents and anonymize legacy withdrawals

Revision ID: 7f2a1c9d4e6b
Revises: be3e3c52de66
Create Date: 2026-07-25 18:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "7f2a1c9d4e6b"
down_revision: str | Sequence[str] | None = "be3e3c52de66"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "user_consents",
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("consent_type", sa.String(length=20), nullable=False),
        sa.Column("version", sa.String(length=50), nullable=False),
        sa.Column("agreed", sa.Boolean(), nullable=False),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "consent_type IN ('terms', 'privacy', 'marketing')",
            name="ck_user_consents_type",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "consent_type",
            "version",
            name="uq_user_consents_user_type_version",
        ),
    )
    op.create_index("ix_user_consents_user_id", "user_consents", ["user_id"])

    # The old API remains live while this migration runs. Its seven-day
    # withdrawal writer can set only deleted_at/grace after the one-time
    # backfill snapshot. Keep a database invariant so that write is still
    # anonymized immediately during the deployment overlap.
    op.execute(
        sa.text(
            """
            CREATE FUNCTION enforce_withdrawn_user_anonymization()
            RETURNS trigger
            LANGUAGE plpgsql
            AS $$
            BEGIN
                IF NEW.deleted_at IS NOT NULL THEN
                    NEW.social_id := 'deleted:' || NEW.id::text;
                    NEW.email := NULL;
                    NEW.nickname := NULL;
                    NEW.birth_date := NULL;
                    NEW.profile_image := NULL;
                    NEW.dna := NULL;
                    NEW.withdrawal_grace_until := NULL;
                    NEW.anonymized_at := COALESCE(
                        NEW.anonymized_at,
                        NEW.deleted_at,
                        CURRENT_TIMESTAMP
                    );
                END IF;
                RETURN NEW;
            END;
            $$
            """
        )
    )
    op.execute(
        sa.text(
            """
            CREATE TRIGGER trg_users_enforce_withdrawn_anonymization
            BEFORE INSERT OR UPDATE ON users
            FOR EACH ROW
            WHEN (NEW.deleted_at IS NOT NULL)
            EXECUTE FUNCTION enforce_withdrawn_user_anonymization()
            """
        )
    )

    op.execute(
        sa.text(
            """
            UPDATE refresh_tokens
            SET deleted_at = COALESCE(deleted_at, CURRENT_TIMESTAMP),
                updated_at = CURRENT_TIMESTAMP
            WHERE deleted_at IS NULL
              AND user_id IN (
                  SELECT id
                  FROM users
                  WHERE deleted_at IS NOT NULL
              )
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE users
            SET social_id = 'deleted:' || id::text,
                email = NULL,
                nickname = NULL,
                birth_date = NULL,
                profile_image = NULL,
                dna = NULL,
                withdrawal_grace_until = NULL,
                anonymized_at = COALESCE(anonymized_at, deleted_at, CURRENT_TIMESTAMP),
                updated_at = CURRENT_TIMESTAMP
            WHERE deleted_at IS NOT NULL
              AND (
                  anonymized_at IS NULL
                  OR social_id NOT LIKE 'deleted:%'
                  OR email IS NOT NULL
                  OR nickname IS NOT NULL
                  OR birth_date IS NOT NULL
                  OR profile_image IS NOT NULL
                  OR dna IS NOT NULL
                  OR withdrawal_grace_until IS NOT NULL
              )
            """
        )
    )


def downgrade() -> None:
    op.execute(
        "DROP TRIGGER IF EXISTS trg_users_enforce_withdrawn_anonymization ON users"
    )
    op.execute("DROP FUNCTION IF EXISTS enforce_withdrawn_user_anonymization()")
    op.drop_index("ix_user_consents_user_id", table_name="user_consents")
    op.drop_table("user_consents")
