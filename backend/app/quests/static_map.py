"""GPS 인증 화면의 지도 배경 — VWorld 정적 지도 프록시 + 디스크 캐시.

docs/specs/050-quest-verification/ (KAN-90)

**퀘스트 좌표로만 지도를 요청한다.** 사용자 위치는 이 경로에 들어오지 않는다 — 내 위치는
단말에서 계산해 이 이미지 위에 오버레이로 그린다. 좌표 비전송 불변식이 지켜지는 지점이
여기다(location-law-review.md). 이 모듈에 사용자 좌표를 받는 파라미터를 추가하지 말 것.

키를 서버가 들고 프록시하는 이유는 두 가지다.
- 앱에 넣으면 APK에서 추출된다.
- GPS 퀘스트는 좌표가 고정이라, 캐시하면 VWorld 호출이 **퀘스트 수만큼**으로 끝난다.
  앱이 직접 부르면 사용자 수만큼 나간다.
"""

import asyncio
import hashlib
import logging
from pathlib import Path

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

_TIMEOUT_SECONDS = 15.0


class StaticMapUnavailable(Exception):
    """지도 배경을 만들지 못했다 — 키 미설정·상류 오류. 호출부는 404로 내린다.

    배경은 참고용이고 인증 판정과 무관하므로, 실패를 인증 실패로 번지게 하지 않는다.
    """


def build_static_map_url(lat: float, lng: float) -> str:
    """VWorld 이미지 API 요청 URL을 만든다.

    2026-08-15 실호출로 검증한 형식이다(200 + PNG). center는 **경도,위도** 순서다.
    """
    return (
        f"{settings.vworld_base_url.rstrip('/')}/req/image"
        "?service=image"
        "&request=getmap"
        f"&key={settings.vworld_api_key.strip()}"
        "&format=png"
        "&basemap=GRAPHIC"
        f"&center={lng},{lat}"
        "&crs=EPSG:4326"
        f"&zoom={settings.map_zoom}"
        f"&size={settings.map_image_width},{settings.map_image_height}"
    )


def cache_path(lat: float, lng: float) -> Path:
    """좌표·줌·크기가 같으면 같은 파일을 쓴다 — 줌·크기를 바꾸면 자연히 새 파일이 된다."""
    digest = hashlib.sha256(
        f"{lat:.6f},{lng:.6f},{settings.map_zoom},"
        f"{settings.map_image_width}x{settings.map_image_height}".encode()
    ).hexdigest()[:32]
    return Path(settings.map_cache_dir) / f"{digest}.png"


async def fetch_quest_map(lat: float, lng: float) -> bytes:
    """퀘스트 좌표의 지도 이미지를 돌려준다. 캐시에 있으면 그대로 쓴다."""
    if not settings.vworld_api_key.strip():
        raise StaticMapUnavailable("VWORLD_API_KEY가 설정되지 않았습니다.")

    path = cache_path(lat, lng)
    if path.exists():
        return await asyncio.to_thread(path.read_bytes)

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT_SECONDS) as client:
            response = await client.get(build_static_map_url(lat, lng))
            response.raise_for_status()
    except httpx.HTTPStatusError as exc:
        logger.error(
            "VWorld 정적 지도 호출 실패 (HTTP %s): %s",
            exc.response.status_code,
            exc.response.text[:300],
        )
        raise StaticMapUnavailable("지도 이미지를 받지 못했습니다.") from exc
    except httpx.HTTPError as exc:
        logger.error("VWorld 정적 지도 호출 실패 (%s): %s", type(exc).__name__, exc)
        raise StaticMapUnavailable("지도 서비스에 연결하지 못했습니다.") from exc

    content = response.content
    # VWorld는 오류도 200 + JSON/텍스트로 돌려주는 경우가 있어 PNG 시그니처를 확인한다.
    # 확인하지 않으면 오류 본문이 그대로 캐시돼 계속 깨진 이미지가 나간다.
    if not content.startswith(b"\x89PNG\r\n\x1a\n"):
        logger.error("VWorld 응답이 PNG가 아닙니다: %s", content[:200])
        raise StaticMapUnavailable("지도 응답 형식이 올바르지 않습니다.")

    await asyncio.to_thread(_write_cache, path, content)
    return content


def _write_cache(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # 같은 좌표를 동시에 요청해도 반쯤 쓰인 파일이 읽히지 않도록 임시 파일 후 교체한다.
    temp = path.with_suffix(".png.tmp")
    temp.write_bytes(content)
    temp.replace(path)
