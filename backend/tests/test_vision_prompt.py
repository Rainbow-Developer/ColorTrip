"""사진 판정 프롬프트 빌더 테스트 — 장소 소개문(KAN-102) 포함 여부를 검증한다."""

import pytest

from app.core.config import settings
from app.integrations.vision.prompt import _OVERVIEW_MAX_CHARS, build_photo_judgement_prompt
from app.quests.verification import _fetch_place_overview


def test_prompt_includes_place_overview() -> None:
    prompt = build_photo_judgement_prompt(
        "중선암 풍경 담기",
        "중선암",
        ["주변 풍경이 보이는 구도"],
        place_overview="단양팔경 중 하나.",
    )
    assert "장소 소개: 단양팔경 중 하나." in prompt
    assert "퀘스트 제목: 중선암 풍경 담기" in prompt


def test_prompt_without_overview_is_unchanged() -> None:
    with_none = build_photo_judgement_prompt("제목", "장소", ["조건"], place_overview=None)
    default = build_photo_judgement_prompt("제목", "장소", ["조건"])
    assert with_none == default
    assert "장소 소개" not in default


def test_prompt_truncates_long_overview() -> None:
    prompt = build_photo_judgement_prompt("제목", "장소", [], place_overview="가" * 1000)
    line = next(ln for ln in prompt.splitlines() if ln.startswith("장소 소개: "))
    assert len(line) == len("장소 소개: ") + _OVERVIEW_MAX_CHARS


async def test_fetch_place_overview_without_content_id_or_key_returns_none(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """수제 퀘스트(content_id 없음)와 키 미설정 환경에서 조회 없이 None을 반환한다."""
    # 실행 환경에 TOUR_API_KEY가 있어도 실제 HTTP가 나가지 않도록 명시적으로 비운다.
    monkeypatch.setattr(settings, "tour_api_key", "")
    assert await _fetch_place_overview(None) is None
    assert await _fetch_place_overview("3558506") is None
