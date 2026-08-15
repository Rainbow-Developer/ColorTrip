"""GPS 인증 배경 지도(VWorld 정적 지도) — docs/specs/050-quest-verification (KAN-90).

핵심 불변식은 두 가지다.
- 이 경로에 **사용자 좌표가 들어오지 않는다** — 퀘스트 좌표로만 지도를 만든다.
- 실패해도 인증을 막지 않는다 — 배경은 참고용이라 404로 내리고 앱은 오버레이만 그린다.
"""

from pathlib import Path

import httpx
import pytest

from app.core.config import settings
from app.quests import static_map

# 최소 크기의 유효한 PNG(1x1) — 시그니처 검사를 통과해야 캐시된다.
_PNG_1X1 = bytes.fromhex(
    "89504e470d0a1a0a0000000d494844520000000100000001080600000"
    "01f15c4890000000a49444154789c6300010000050001"
    "0d0a2db40000000049454e44ae426082"
)


@pytest.fixture(autouse=True)
def _isolated_cache(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """캐시를 테스트마다 격리한다 — 실제 캐시 디렉토리를 건드리지 않는다."""
    monkeypatch.setattr(settings, "map_cache_dir", str(tmp_path / "map_cache"))
    monkeypatch.setattr(settings, "vworld_api_key", "test-key")


def _patch_transport(
    monkeypatch: pytest.MonkeyPatch,
    handler: object,
) -> None:
    transport = httpx.MockTransport(handler)  # type: ignore[arg-type]
    original_client = httpx.AsyncClient

    def patched_client(*args: object, **kwargs: object) -> httpx.AsyncClient:
        kwargs["transport"] = transport
        return original_client(*args, **kwargs)  # type: ignore[arg-type]

    monkeypatch.setattr(httpx, "AsyncClient", patched_client)


def test_url은_경도_위도_순서로_center를_넣는다() -> None:
    """VWorld는 center를 경도,위도 순으로 받는다 — 뒤집으면 엉뚱한 곳이 나온다."""
    url = static_map.build_static_map_url(37.0008, 128.3418)

    assert "center=128.3418,37.0008" in url
    assert f"zoom={settings.map_zoom}" in url
    assert f"size={settings.map_image_width},{settings.map_image_height}" in url
    assert "crs=EPSG:4326" in url


def test_프론트_상수와_서버_설정이_일치한다() -> None:
    """FE `gps_verify_map.dart`의 kMapImageWidthPx/HeightPx/kMapZoom과 같아야 한다.

    어긋나면 앱이 그리는 반경 원·내 위치가 배경 지도와 어긋난다. 값을 바꿀 때는 양쪽을
    함께 고쳐야 한다는 것을 이 테스트가 강제한다.
    """
    assert settings.map_image_width == 640
    assert settings.map_image_height == 360
    assert settings.map_zoom == 15


async def test_키가_없으면_지도를_만들지_않는다(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "vworld_api_key", "")

    with pytest.raises(static_map.StaticMapUnavailable):
        await static_map.fetch_quest_map(37.0008, 128.3418)


async def test_받은_이미지를_캐시하고_두_번째부터는_호출하지_않는다(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """퀘스트 좌표는 고정이라 캐시가 곧 VWorld 호출 상한이다."""
    calls = {"count": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        calls["count"] += 1
        return httpx.Response(200, content=_PNG_1X1)

    _patch_transport(monkeypatch, handler)

    first = await static_map.fetch_quest_map(37.0008, 128.3418)
    second = await static_map.fetch_quest_map(37.0008, 128.3418)

    assert first == second == _PNG_1X1
    assert calls["count"] == 1, "캐시가 있으면 상류를 다시 부르지 않아야 한다"
    assert static_map.cache_path(37.0008, 128.3418).exists()


async def test_PNG가_아닌_응답은_실패로_보고_캐시하지_않는다(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """VWorld는 오류를 200 + 텍스트로 주기도 한다.

    시그니처를 확인하지 않으면 그 본문이 캐시에 눌러앉아 계속 깨진 이미지가 나간다.
    """

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, text="ERROR: invalid key")

    _patch_transport(monkeypatch, handler)

    with pytest.raises(static_map.StaticMapUnavailable):
        await static_map.fetch_quest_map(37.0008, 128.3418)

    assert not static_map.cache_path(37.0008, 128.3418).exists()


async def test_상류_오류는_인증을_막지_않고_전용_예외로_바뀐다(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500, text="upstream down")

    _patch_transport(monkeypatch, handler)

    with pytest.raises(static_map.StaticMapUnavailable):
        await static_map.fetch_quest_map(37.0008, 128.3418)


def test_캐시_키는_좌표와_줌_크기에_따라_달라진다(monkeypatch: pytest.MonkeyPatch) -> None:
    a = static_map.cache_path(37.0008, 128.3418)
    b = static_map.cache_path(37.0009, 128.3418)
    assert a != b, "좌표가 다르면 다른 파일이어야 한다"

    monkeypatch.setattr(settings, "map_zoom", settings.map_zoom + 1)
    assert static_map.cache_path(37.0008, 128.3418) != a, (
        "줌을 바꾸면 옛 이미지를 재사용하면 안 된다"
    )
