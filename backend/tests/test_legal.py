"""공개 법적 문서와 동의 metadata 회귀 테스트."""

from __future__ import annotations

from httpx import AsyncClient

from app.core.config import settings


async def test_terms_and_privacy_are_public_versioned_documents(client: AsyncClient) -> None:
    terms = await client.get("/terms")
    privacy = await client.get("/privacy")

    assert terms.status_code == 200
    assert "이용약관" in terms.text
    assert "terms-v2" in terms.text
    assert privacy.status_code == 200
    assert "개인정보처리방침" in privacy.text
    assert "privacy-v2" in privacy.text
    assert "위치정보" in privacy.text
    assert "여행 성향" in privacy.text
    assert "공유 코드" in privacy.text


async def test_account_deletion_page_is_public_and_actionable(
    client: AsyncClient,
    monkeypatch,
) -> None:
    monkeypatch.setattr(settings, "legal_operator_name", "전주호 (무지개발자)")
    monkeypatch.setattr(settings, "legal_privacy_officer_email", "rainbow.dev00@gmail.com")
    monkeypatch.setattr(
        settings,
        "legal_aggregate_retention_period",
        "개인 식별정보 제거 후 통계 목적 달성 또는 서비스 종료 시까지",
    )
    response = await client.get("/account-deletion")

    assert response.status_code == 200
    assert "다채로울지도(ColorTrip)" in response.text
    assert "무지개발자" in response.text
    assert "프로필" in response.text
    assert "회원 탈퇴" in response.text
    assert "rainbow.dev00@gmail.com" in response.text
    assert "계정 삭제 요청" in response.text
    assert "일부 데이터 삭제" in response.text
    assert "삭제되는 데이터" in response.text
    assert "보존되는 데이터" in response.text
    assert "비밀번호" in response.text
    assert "10일 이내" in response.text
    assert "<form" not in response.text
