"""공개 법적 문서와 동의 metadata 회귀 테스트."""

from __future__ import annotations

from httpx import AsyncClient


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
