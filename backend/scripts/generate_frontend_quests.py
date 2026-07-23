"""TourAPI(KorService2)로 충북 11개 시·군 관광정보를 수집해
frontend/lib/data/static/quests_data.dart를 시·군당 20개(총 220개)로 확장하는 생성 스크립트.

- 수제 퀘스트(지역별 id 1~5번)는 유지하고, 지역당 15개(6~20번)를 API 데이터로 생성한다.
- 분류코드(cat1/cat2)·contentTypeId → 앱 퀘스트 유형(nature/food/history/active/healing) 매핑.
- 설명(desc)은 detailCommon2의 소개문(overview) 첫 문장, 없으면 유형별 템플릿.
- TourAPI 사용법·시군구 코드: docs/conventions/external-apis.md

실행 (backend/.env의 TOUR_API_KEY 필요):
    cd backend && uv run python scripts/generate_frontend_quests.py

주의: 이미 생성분(id 6~20번)이 들어간 파일에 재실행하면 중단한다(중복 방지).
생성 후 컨테이너에서 `dart format`·`flutter test`를 돌려 검증한다.
"""

import asyncio
import re
import sys
from pathlib import Path
from typing import Any

import httpx

REPO = Path(__file__).resolve().parents[2]
ENV = REPO / "backend" / ".env"
DART = REPO / "frontend" / "lib" / "data" / "static" / "quests_data.dart"

TARGET_PER_REGION = 20  # 기존 수제 5 + 생성 15

# region id / TourAPI 시군구명 / 퀘스트 id prefix
# / 다음 지역 첫 퀘스트 id(삽입 앵커; None=리스트 끝)
REGIONS = [
    ("danyang", "단양군", "dy", "cj1"),
    ("cheongju", "청주시", "cj", "be1"),
    ("boeun", "보은군", "be", "cu1"),
    ("chungju", "충주시", "cu", "jc1"),
    ("jecheon", "제천시", "jc", "es1"),
    ("eumseong", "음성군", "es", "jh1"),
    ("jincheon", "진천군", "jh", "jp1"),
    ("jeungpyeong", "증평군", "jp", "gs1"),
    ("goesan", "괴산군", "gs", "oc1"),
    ("okcheon", "옥천군", "oc", "yd1"),
    ("yeongdong", "영동군", "yd", None),
]

# 수제 퀘스트(1~5번)와 중복되는 명소 제외(제목에 포함되면 skip)
BLOCKLIST = {
    "danyang": ["소백산", "연화봉", "도담삼봉", "마늘", "구경시장", "만천하", "온달"],
    "cheongju": ["고인쇄", "직지", "수암골", "서문시장", "삼겹살", "상당산성", "청남대"],
    "boeun": ["법주사", "문장대", "말티재", "세조길", "대추"],
    "chungju": ["충주호", "탄금대", "활옥동굴", "사과", "중앙탑", "탑평리"],
    "jecheon": ["청풍호반", "케이블카", "의림지", "옥순봉", "배론성지", "약채락"],
    "eumseong": ["큰바위얼굴", "봉학골", "감곡매괴", "무극시장", "설성공원"],
    "jincheon": ["농다리", "미르309", "초평호", "보탑사", "생거진천 전통시장", "만뢰산"],
    "jeungpyeong": ["좌구산", "삼기저수지", "등잔길", "김득신", "인삼"],
    "goesan": ["산막이", "화양", "수옥폭포", "옥수수"],
    "okcheon": ["정지용", "부소담악", "향수호수", "생선국수"],
    "yeongdong": ["와인터널", "월류봉", "영국사", "물한계곡", "난계"],
}

# 지역당 20개 기준 유형 목표(합 20). 기존 5개 분포를 빼고 남은 수만큼 API 데이터로 채운다.
TYPE_TARGET = {"nature": 5, "history": 5, "food": 4, "healing": 3, "active": 3}

# 수제 퀘스트(1~5번)의 유형 분포 — quests_data.dart와 일치해야 한다.
EXISTING_TYPES = {
    "danyang": ["nature", "nature", "food", "active", "history"],
    "cheongju": ["history", "healing", "food", "active", "nature"],
    "boeun": ["history", "active", "nature", "healing", "food"],
    "chungju": ["healing", "history", "active", "food", "history"],
    "jecheon": ["nature", "healing", "active", "history", "food"],
    "eumseong": ["history", "nature", "history", "food", "healing"],
    "jincheon": ["history", "active", "history", "food", "nature"],
    "jeungpyeong": ["active", "healing", "history", "food", "nature"],
    "goesan": ["nature", "nature", "healing", "food", "history"],
    "okcheon": ["history", "nature", "healing", "food", "history"],
    "yeongdong": ["food", "nature", "history", "healing", "active"],
}

COMMON = {"MobileOS": "ETC", "MobileApp": "ColorTrip", "_type": "json"}

TITLE_TPL = {
    "nature": ["{t} 풍경 담기", "{t} 자연 산책", "{t} 절경 인증샷"],
    "history": ["{t} 둘러보기", "{t}에서 역사 한 조각", "{t} 방문 인증"],
    "food": ["{t} 맛보기", "{t} 미식 탐방", "{t}에서 한 끼"],
    "healing": ["{t}에서 쉬어가기", "{t} 느긋한 산책", "{t} 힐링 타임"],
    "active": ["{t} 도전하기", "{t} 체험 인증", "{t}에서 액티비티"],
}
DESC_TPL = {
    "nature": "{t}의 자연 풍경 속에서 여유로운 한때를 보내고 사진으로 남겨보세요.",
    "history": "{t}에 깃든 이야기를 따라 걸으며 방문을 인증해보세요.",
    "food": "{t}에서 지역의 맛을 즐기고 음식 사진으로 기록해보세요.",
    "healing": "{t}에서 잠시 쉬어가며 느린 여행의 매력을 느껴보세요.",
    "active": "{t}에서 몸으로 부딪치는 즐거움을 경험하고 인증해보세요.",
}
COND_PHOTO = {
    "nature": ["{t}에서 촬영", "주변 풍경이 보이는 구도"],
    "history": ["{t}에서 촬영", "장소가 알아볼 수 있게 나온 사진"],
    "food": ["음식이 명확히 보이는 사진", "{t}에서 촬영"],
    "healing": ["{t}에서 촬영"],
    "active": ["체험 모습이 보이는 사진", "{t}에서 촬영"],
}
COND_GPS = ["{t} 도착(인증 반경 이내)", "GPS 위치 인증"]

REWARD = {"nature": 80, "history": 70, "food": 60, "healing": 60, "active": 90}

KEY, BASE = "", ""

SEM = asyncio.Semaphore(5)
MAX_TRIES = 8  # 발급 직후 키는 게이트웨이 전파 전까지 401이 간헐적으로 섞인다(external-apis.md)


def load_key() -> tuple[str, str]:
    env: dict[str, str] = {}
    for line in ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip()
    key = env.get("TOUR_API_KEY", "")
    base = env.get("TOUR_API_BASE_URL", "https://apis.data.go.kr/B551011/KorService2")
    if not key:
        sys.exit("TOUR_API_KEY가 backend/.env에 비어 있습니다.")
    return key, base


def items_of(data: Any) -> list[dict[str, Any]]:
    node: Any = data
    for k in ("response", "body", "items"):
        if not isinstance(node, dict):
            return []
        node = node.get(k, {})
    if not isinstance(node, dict):
        return []
    item = node.get("item")
    if item is None:
        return []
    return [item] if isinstance(item, dict) else item


async def get(client: httpx.AsyncClient, endpoint: str, **params: str) -> list[dict[str, Any]]:
    async with SEM:
        for attempt in range(1, MAX_TRIES + 1):
            try:
                r = await client.get(
                    f"{BASE}/{endpoint}", params={"serviceKey": KEY, **COMMON, **params}
                )
                r.raise_for_status()
                return items_of(r.json())
            except Exception as e:  # noqa: BLE001 - 재시도 후 포기
                if attempt == MAX_TRIES:
                    print(f"  ! {endpoint} {params.get('contentId', '')} 실패: {e}")
                    return []
                await asyncio.sleep(min(1.5 * attempt, 6.0))
    return []


def classify(item: dict[str, Any]) -> str | None:
    ct = str(item.get("contenttypeid", ""))
    cat1 = item.get("cat1", "") or ""
    cat2 = item.get("cat2", "") or ""
    if ct == "39" or cat1 == "A05":
        return "food"
    if ct == "28" or cat1 == "A03":
        return "active"
    if cat1 == "A01":
        return "nature"
    if cat1 == "A02":
        return {
            "A0201": "history",
            "A0202": "healing",
            "A0203": "active",
            "A0204": "history",
            "A0205": "history",
            "A0206": "history",
        }.get(cat2)
    return None


def clean_title(raw: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"\[.*?\]", "", raw)).strip()


def clean_overview(raw: str, place: str, qtype: str) -> str:
    text = re.sub(r"<[^>]+>", " ", raw or "")
    text = text.replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&")
    text = re.sub(r"\s+", " ", text).strip()
    m = re.match(r"(.{15,90}?(?:다|요)\.)\s", text + " ")
    if m:
        return m.group(1)
    if 15 <= len(text) <= 90:
        return text
    return DESC_TPL[qtype].format(t=place)


def dart_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


async def collect_region(
    client: httpx.AsyncClient, region_id: str, sigungu_code: str
) -> list[dict[str, Any]]:
    """관광지(12)·문화시설(14)·레포츠(28)·음식점(39)을 모아 유형 분류·중복 제거한 후보 풀."""
    pool: list[dict[str, Any]] = []
    for ctid in ("12", "14", "28", "39"):
        pool.extend(
            await get(
                client,
                "areaBasedList2",
                areaCode="33",
                sigunguCode=sigungu_code,
                contentTypeId=ctid,
                numOfRows="100",
                pageNo="1",
            )
        )
    seen: set[str] = set()
    out: list[dict[str, Any]] = []
    block = BLOCKLIST[region_id]
    for it in pool:
        title = clean_title(it.get("title", ""))
        qtype = classify(it)
        if not title or not qtype or not it.get("contentid"):
            continue
        if any(b in title for b in block):
            continue
        key = re.sub(r"\s", "", title)
        if key in seen:
            continue
        seen.add(key)
        out.append(
            {
                "content_id": str(it["contentid"]),
                "title": title,
                "type": qtype,
                "has_image": bool(it.get("firstimage")),
                "has_coord": bool(it.get("mapx")) and bool(it.get("mapy")),
                "modified": str(it.get("modifiedtime", "")),
            }
        )
    return out


def pick(region_id: str, pool: list[dict[str, Any]], count: int) -> list[dict[str, Any]]:
    """유형 목표(TYPE_TARGET - 기존 분포)에 맞춰 count개 선정. 대표 이미지 보유·최신 수정 우선."""
    need = dict(TYPE_TARGET)
    for t in EXISTING_TYPES[region_id]:
        need[t] = max(0, need.get(t, 0) - 1)
    by_type: dict[str, list[dict[str, Any]]] = {}
    for it in pool:
        by_type.setdefault(it["type"], []).append(it)
    for lst in by_type.values():
        lst.sort(key=lambda x: (x["has_image"], x["modified"]), reverse=True)

    chosen: list[dict[str, Any]] = []
    for t, n in need.items():
        chosen.extend(by_type.get(t, [])[:n])
    if len(chosen) < count:  # 유형 목표를 못 채우면 남은 후보로 보충
        used = {c["content_id"] for c in chosen}
        rest = [it for it in pool if it["content_id"] not in used]
        rest.sort(key=lambda x: (x["has_image"], x["modified"]), reverse=True)
        chosen.extend(rest[: count - len(chosen)])
    return chosen[:count]


def render(region_id: str, prefix: str, chosen: list[dict[str, Any]]) -> str:
    lines: list[str] = []
    gps_used = 0
    for i, it in enumerate(chosen):
        idx = 6 + i  # 수제 1~5번 다음
        qtype = it["type"]
        place = it["title"]
        title = TITLE_TPL[qtype][i % 3].format(t=place)
        verify = "photo"
        if qtype == "active" and it["has_coord"] and gps_used < 2:
            verify, gps_used = "gps", gps_used + 1
        reward = REWARD[qtype] + (20 if verify == "gps" else 0)
        conds = COND_GPS if verify == "gps" else COND_PHOTO[qtype]
        cond_str = ", ".join(dart_str(c.format(t=place)) for c in conds)
        lines.append(
            f"""  Quest(
    id: '{prefix}{idx}',
    region: '{region_id}',
    type: '{qtype}',
    title: {dart_str(title)},
    place: {dart_str(place)},
    verify: '{verify}',
    reward: {reward},
    desc: {dart_str(it["desc"])},
    conditions: [{cond_str}],
  ),
"""
        )
    return "".join(lines)


async def main() -> None:
    global KEY, BASE
    KEY, BASE = load_key()

    src = DART.read_text(encoding="utf-8")
    if "id: 'dy6'" in src:
        sys.exit("이미 생성분(id 6~20번)이 있습니다 — 중복 삽입 방지를 위해 중단합니다.")

    async with httpx.AsyncClient(timeout=15.0) as client:
        sigungus = await get(client, "areaCode2", areaCode="33", numOfRows="50")
        code_by_name = {s["name"]: str(s["code"]) for s in sigungus}
        print("시군구 코드:", code_by_name)

        blocks: dict[str, str] = {}
        for region_id, kname, prefix, _anchor in REGIONS:
            code = code_by_name.get(kname)
            if not code:
                sys.exit(f"{kname} 시군구 코드를 찾지 못했습니다: {code_by_name}")
            pool = await collect_region(client, region_id, code)
            chosen = pick(region_id, pool, TARGET_PER_REGION - 5)
            if len(chosen) < TARGET_PER_REGION - 5:
                print(f"  ! {kname}: 후보 부족({len(chosen)}/15) — 있는 만큼만 추가")
            details = await asyncio.gather(
                *(get(client, "detailCommon2", contentId=c["content_id"]) for c in chosen)
            )
            for c, d in zip(chosen, details, strict=True):
                overview = d[0].get("overview", "") if d else ""
                c["desc"] = clean_overview(overview, c["title"], c["type"])
            blocks[region_id] = render(region_id, prefix, chosen)
            types = [c["type"] for c in chosen]
            counts = {t: types.count(t) for t in sorted(set(types))}
            print(f"{kname}: {len(chosen)}개 추가 {counts}")

    for region_id, _kname, _prefix, anchor in REGIONS:
        block = blocks[region_id]
        if anchor:
            marker = f"  Quest(\n    id: '{anchor}',"
            assert marker in src, f"앵커 없음: {anchor}"
            src = src.replace(marker, block + marker, 1)
        else:
            src = src.replace("\n];", "\n" + block + "];", 1)

    DART.write_text(src, encoding="utf-8", newline="\n")
    total = src.count("id: '")
    print(f"완료 — quests_data.dart 총 {total}개 항목")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[union-attr]
    asyncio.run(main())
