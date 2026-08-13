from __future__ import annotations

import asyncio
from datetime import date, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select

from app.auth import schemas as auth_schemas
from app.auth.models import User, UserConsent
from app.auth.schemas import OnboardingProfileRequest
from app.core.base import now_kst
from app.core.database import AsyncSessionLocal
from tests.helpers import login


def _onboarding_payload(**overrides: object) -> dict[str, object]:
    payload: dict[str, object] = {
        "nickname": "  컬러트립  ",
        "email": "  USER@Example.COM ",
        "birth_date": "2000-01-02",
        "terms_agreed": True,
        "privacy_agreed": True,
        "marketing_agreed": False,
    }
    payload.update(overrides)
    return payload


@pytest.mark.asyncio
async def test_onboarding_profile_atomically_normalizes_profile_and_records_consents(
    client: AsyncClient,
) -> None:
    login_data = await login(client)
    response = await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers={"Authorization": f"Bearer {login_data['access_token']}"},
        json=_onboarding_payload(),
    )

    assert response.status_code == 200
    assert response.json()["data"] == {
        **login_data["user"],
        "nickname": "컬러트립",
        "email": "user@example.com",
        "birth_date": "2000-01-02",
        "onboarding_step": "trip_dna",
    }

    user_id = UUID(login_data["user"]["id"])
    async with AsyncSessionLocal() as session:
        consents = list(
            (
                await session.scalars(
                    select(UserConsent)
                    .where(UserConsent.user_id == user_id)
                    .order_by(UserConsent.consent_type)
                )
            ).all()
        )

    assert [(consent.consent_type, consent.version, consent.agreed) for consent in consents] == [
        ("marketing", "marketing-v1", False),
        ("privacy", "privacy-v1", True),
        ("terms", "terms-v1", True),
    ]
    assert all(consent.decided_at is not None for consent in consents)


@pytest.mark.asyncio
async def test_onboarding_profile_is_idempotent_for_retries_and_concurrent_requests(
    client: AsyncClient,
) -> None:
    login_data = await login(client)
    headers = {"Authorization": f"Bearer {login_data['access_token']}"}

    responses = await asyncio.gather(
        *(
            client.put(
                "/api/v1/users/me/onboarding-profile",
                headers=headers,
                json=_onboarding_payload(),
            )
            for _ in range(5)
        )
    )

    assert all(response.status_code == 200 for response in responses)
    assert len({str(response.json()["data"]) for response in responses}) == 1

    async with AsyncSessionLocal() as session:
        consent_count = await session.scalar(
            select(func.count())
            .select_from(UserConsent)
            .where(UserConsent.user_id == UUID(login_data["user"]["id"]))
        )
    assert consent_count == 3


@pytest.mark.asyncio
async def test_identical_onboarding_retry_preserves_consent_decision_timestamps(
    client: AsyncClient,
) -> None:
    login_data = await login(client)
    headers = {"Authorization": f"Bearer {login_data['access_token']}"}
    first = await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers=headers,
        json=_onboarding_payload(),
    )
    assert first.status_code == 200

    user_id = UUID(login_data["user"]["id"])
    async with AsyncSessionLocal() as session:
        before = {
            consent.consent_type: (consent.decided_at, consent.updated_at)
            for consent in (
                await session.scalars(select(UserConsent).where(UserConsent.user_id == user_id))
            ).all()
        }

    second = await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers=headers,
        json=_onboarding_payload(),
    )
    assert second.status_code == 200

    async with AsyncSessionLocal() as session:
        after = {
            consent.consent_type: (consent.decided_at, consent.updated_at)
            for consent in (
                await session.scalars(select(UserConsent).where(UserConsent.user_id == user_id))
            ).all()
        }
    assert after == before


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "override",
    [
        {"terms_agreed": 1},
        {"privacy_agreed": "true"},
        {"marketing_agreed": 0},
    ],
)
async def test_onboarding_consent_flags_require_json_booleans(
    client: AsyncClient,
    override: dict[str, object],
) -> None:
    login_data = await login(client)
    response = await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers={"Authorization": f"Bearer {login_data['access_token']}"},
        json=_onboarding_payload(**override),
    )

    assert response.status_code == 422


def test_birth_date_validation_uses_current_kst_date(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    fixed_kst_now = datetime(2026, 1, 1, 0, 30, tzinfo=ZoneInfo("Asia/Seoul"))
    monkeypatch.setattr(auth_schemas, "now_kst", lambda: fixed_kst_now, raising=False)

    accepted = OnboardingProfileRequest.model_validate(_onboarding_payload(birth_date="2026-01-01"))
    assert accepted.birth_date == date(2026, 1, 1)

    with pytest.raises(ValueError, match="birth_date"):
        OnboardingProfileRequest.model_validate(_onboarding_payload(birth_date="2026-01-02"))


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("override", "expected_status"),
    [
        ({"nickname": "   "}, 422),
        ({"nickname": "가" * 31}, 422),
        ({"email": "not-an-email"}, 422),
        ({"email": "x" * 250 + "@a.com"}, 422),
        # 서버는 KST 기준으로 미래 날짜를 판정한다(`now_kst()`). 러너의 로컬 날짜(UTC)로
        # 계산하면 00~09시 KST 구간에서 "내일"이 KST의 오늘과 같아져 통과해버린다.
        ({"birth_date": (now_kst().date() + timedelta(days=1)).isoformat()}, 422),
        ({"terms_agreed": False}, 400),
        ({"privacy_agreed": False}, 400),
    ],
)
async def test_invalid_onboarding_profile_saves_nothing(
    client: AsyncClient,
    override: dict[str, object],
    expected_status: int,
) -> None:
    login_data = await login(client)
    user_id = UUID(login_data["user"]["id"])

    response = await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers={"Authorization": f"Bearer {login_data['access_token']}"},
        json=_onboarding_payload(**override),
    )

    assert response.status_code == expected_status
    async with AsyncSessionLocal() as session:
        user = await session.get(User, user_id)
        consent_count = await session.scalar(
            select(func.count()).select_from(UserConsent).where(UserConsent.user_id == user_id)
        )
    assert user is not None
    assert user.nickname == "one"
    assert user.email == "one@example.com"
    assert user.birth_date is None
    assert consent_count == 0


@pytest.mark.asyncio
async def test_onboarding_step_uses_only_current_required_consent_versions(
    client: AsyncClient,
) -> None:
    login_data = await login(client)
    user_id = UUID(login_data["user"]["id"])
    async with AsyncSessionLocal() as session:
        user = await session.get(User, user_id)
        assert user is not None
        user.birth_date = date(2000, 1, 2)
        session.add_all(
            [
                UserConsent(
                    user_id=user_id,
                    consent_type="terms",
                    version="terms-v0",
                    agreed=True,
                    decided_at=now_kst(),
                ),
                UserConsent(
                    user_id=user_id,
                    consent_type="privacy",
                    version="privacy-v1",
                    agreed=True,
                    decided_at=now_kst(),
                ),
            ]
        )
        await session.commit()

    response = await client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {login_data['access_token']}"},
    )

    assert response.status_code == 200
    assert response.json()["data"]["onboarding_step"] == "profile"


@pytest.mark.asyncio
async def test_patch_profile_allows_only_nickname_and_birth_date_for_current_user(
    client: AsyncClient,
) -> None:
    login_data = await login(client)
    headers = {"Authorization": f"Bearer {login_data['access_token']}"}
    await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers=headers,
        json=_onboarding_payload(),
    )
    async with AsyncSessionLocal() as session:
        user = await session.get(User, UUID(login_data["user"]["id"]))
        assert user is not None
        user.dna = "nature"
        await session.commit()

    response = await client.patch(
        "/api/v1/users/me",
        headers=headers,
        json={"nickname": "  새 닉네임 ", "birth_date": "1999-12-31"},
    )
    email_attempt = await client.patch(
        "/api/v1/users/me",
        headers=headers,
        json={"email": "other@example.com"},
    )

    assert response.status_code == 200
    assert response.json()["data"]["nickname"] == "새 닉네임"
    assert response.json()["data"]["birth_date"] == "1999-12-31"
    assert response.json()["data"]["email"] == "user@example.com"
    assert response.json()["data"]["onboarding_step"] == "complete"
    assert email_attempt.status_code == 422


@pytest.mark.asyncio
async def test_completed_user_cannot_change_email_through_onboarding_endpoint(
    client: AsyncClient,
) -> None:
    login_data = await login(client)
    headers = {"Authorization": f"Bearer {login_data['access_token']}"}
    onboarded = await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers=headers,
        json=_onboarding_payload(),
    )
    assert onboarded.status_code == 200

    async with AsyncSessionLocal() as session:
        user = await session.get(User, UUID(login_data["user"]["id"]))
        assert user is not None
        user.dna = "nature"
        await session.commit()

    changed = await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers=headers,
        json=_onboarding_payload(email="other@example.com"),
    )
    profile = await client.get("/api/v1/users/me", headers=headers)

    assert changed.status_code == 422
    assert changed.json()["code"] == "VALIDATION_ERROR"
    assert profile.status_code == 200
    assert profile.json()["data"]["email"] == "user@example.com"
    assert profile.json()["data"]["onboarding_step"] == "complete"


@pytest.mark.asyncio
async def test_staged_dependencies_gate_trip_dna_and_domain_apis(
    client: AsyncClient,
) -> None:
    login_data = await login(client)
    headers = {"Authorization": f"Bearer {login_data['access_token']}"}

    active_questions = await client.get("/api/v1/trip_dna/questions", headers=headers)
    active_replies = await client.post(
        "/api/v1/trip_dna/replies",
        headers=headers,
        json={"replies": []},
    )
    active_patch = await client.patch(
        "/api/v1/users/me",
        headers=headers,
        json={"nickname": "blocked"},
    )
    for response in (active_questions, active_replies, active_patch):
        assert response.status_code == 403
        assert response.json()["code"] == "ONBOARDING_REQUIRED"

    onboarded = await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers=headers,
        json=_onboarding_payload(),
    )
    profiled_questions = await client.get("/api/v1/trip_dna/questions", headers=headers)
    profiled_map = await client.get("/api/v1/users/me/map", headers=headers)

    assert onboarded.status_code == 200
    assert profiled_questions.status_code == 200
    assert profiled_map.status_code == 403
    assert profiled_map.json()["code"] == "ONBOARDING_REQUIRED"

    async with AsyncSessionLocal() as session:
        user = await session.get(User, UUID(login_data["user"]["id"]))
        assert user is not None
        user.dna = "nature"
        await session.commit()

    current_map = await client.get("/api/v1/users/me/map", headers=headers)
    assert current_map.status_code == 200


@pytest.mark.asyncio
async def test_active_user_can_logout_and_withdraw_before_onboarding(client: AsyncClient) -> None:
    logout_data = await login(client)
    logout = await client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": f"Bearer {logout_data['access_token']}"},
        json={"refresh_token": logout_data["refresh_token"]},
    )
    withdraw_data = await login(client, "kakao-token-unknown")
    withdrawal = await client.delete(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {withdraw_data['access_token']}"},
    )

    assert logout.status_code == 200
    assert withdrawal.status_code == 200


@pytest.mark.asyncio
async def test_onboarding_profile_accepts_missing_birth_date(client: AsyncClient) -> None:
    """생년월일은 선택 항목이다 — 없이 제출해도 온보딩이 다음 단계로 넘어간다 (KAN-75).

    프로필 완료 판정에 생년월일이 남아 있으면 건너뛴 사용자가 onboarding_step="profile"에
    묶여 회원가입 화면을 벗어나지 못한다.
    """
    login_data = await login(client)
    payload = _onboarding_payload()
    del payload["birth_date"]

    response = await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers={"Authorization": f"Bearer {login_data['access_token']}"},
        json=payload,
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["birth_date"] is None
    assert data["onboarding_step"] == "trip_dna"


@pytest.mark.asyncio
async def test_onboarding_retry_without_birth_date_keeps_saved_value(
    client: AsyncClient,
) -> None:
    """생년월일을 넣어 저장한 뒤 빼고 재제출해도 기존 값을 지우지 않는다 (KAN-75)."""
    login_data = await login(client)
    headers = {"Authorization": f"Bearer {login_data['access_token']}"}
    first = await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers=headers,
        json=_onboarding_payload(),
    )
    assert first.status_code == 200

    payload = _onboarding_payload()
    del payload["birth_date"]
    second = await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers=headers,
        json=payload,
    )

    assert second.status_code == 200
    assert second.json()["data"]["birth_date"] == "2000-01-02"


@pytest.mark.asyncio
async def test_first_onboarding_submit_may_change_kakao_prefilled_email(
    client: AsyncClient,
) -> None:
    """카카오가 채워준 이메일은 첫 온보딩 제출에서 바꿀 수 있어야 한다 (회귀: KAN-75).

    이메일 잠금을 "필드가 채워졌는가"로 판단하면, 생년월일이 선택으로 바뀐 뒤 카카오
    프리필만으로 잠금 조건이 성립해 신규 가입자가 첫 제출부터 막힌다. 잠금 기준은
    "온보딩(동의 포함)을 마쳤는가"여야 한다.
    """
    login_data = await login(client)
    assert login_data["user"]["email"] is not None  # 카카오 프리필 전제

    response = await client.put(
        "/api/v1/users/me/onboarding-profile",
        headers={"Authorization": f"Bearer {login_data['access_token']}"},
        json=_onboarding_payload(email="changed@example.com"),
    )

    assert response.status_code == 200
    assert response.json()["data"]["email"] == "changed@example.com"
