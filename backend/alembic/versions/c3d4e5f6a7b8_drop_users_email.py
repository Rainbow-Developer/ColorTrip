"""drop users.email

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-08-13
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "c3d4e5f6a7b8"
down_revision: str | Sequence[str] | None = "b2c3d4e5f6a7"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


# 7f2a1c9d4e6b이 만든 익명화 trigger 함수의 본문. 컬럼을 지우기 전에 이 함수에서 email
# 참조를 먼저 걷어내야 한다 — plpgsql은 지연 바인딩이라 함수 정의 시점에는 통과하고
# 탈퇴 UPDATE가 실행될 때 비로소 `column "email" does not exist`로 터진다.
_ANONYMIZATION_FUNCTION = """
CREATE OR REPLACE FUNCTION enforce_withdrawn_user_anonymization()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.deleted_at IS NOT NULL THEN
        NEW.social_id := 'deleted:' || NEW.id::text;
{email_assignment}        NEW.nickname := NULL;
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

_EMAIL_ASSIGNMENT = "        NEW.email := NULL;\n"


def upgrade() -> None:
    op.execute(sa.text(_ANONYMIZATION_FUNCTION.format(email_assignment="")))
    op.drop_column("users", "email")


def downgrade() -> None:
    # 컬럼 구조만 되돌린다. 저장돼 있던 주소는 upgrade에서 영구 소실되므로 전부 NULL이다.
    op.add_column("users", sa.Column("email", sa.String(length=255), nullable=True))
    op.execute(sa.text(_ANONYMIZATION_FUNCTION.format(email_assignment=_EMAIL_ASSIGNMENT)))
