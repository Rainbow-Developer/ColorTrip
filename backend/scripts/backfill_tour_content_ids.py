"""정적 퀘스트에 TourAPI contentId를 백필하고 저장된 공사 데이터를 걷어낸다 (KAN-102).

- quests_data.dart: 각 Quest에 tourContentId·tourContentTypeId를 삽입하고,
  TourAPI 유래 저장 데이터인 imageUrl(전체)·desc(생성 퀘스트: id 숫자 6 이상)를 제거한다.
  좌표(lat/lng)는 GPS 인증 반경 판정에 쓰이므로 유지한다(090 스펙 비목표).
- backend/alembic/data/kan102_tour_content_ids.json: client_key → {content_id,
  content_type_id} 매핑을 기록한다(서버 quests.content_id 백필 마이그레이션 입력).

매칭은 enrich_frontend_quests.py와 동일: areaBasedList2(지역×유형 4종) 제목 매칭 →
실패 시 searchKeyword2(주소 필터) 보충. 미매칭 퀘스트는 필드 없이 둔다(placeholder 표시).

실행 (backend/.env의 TOUR_API_KEY 필요):
    uv run --project backend python backend/scripts/backfill_tour_content_ids.py
"""

import asyncio
import json
import re
import sys
from pathlib import Path
from typing import Any

import httpx

ROOT = Path(__file__).resolve().parents[2]
DART = ROOT / "frontend" / "lib" / "data" / "static" / "quests_data.dart"
ENV = ROOT / "backend" / ".env"
MAPPING_JSON = ROOT / "backend" / "alembic" / "data" / "kan102_tour_content_ids.json"

REGION_NAMES = {
    "danyang": "단양군",
    "cheongju": "청주시",
    "boeun": "보은군",
    "chungju": "충주시",
    "jecheon": "제천시",
    "eumseong": "음성군",
    "jincheon": "진천군",
    "jeungpyeong": "증평군",
    "goesan": "괴산군",
    "okcheon": "옥천군",
    "yeongdong": "영동군",
}

# 키워드 검색 별칭 — enrich_frontend_quests.py와 동일(정적 장소명 ↔ TourAPI 표기 차이)
KEYWORD_ALIAS = {
    "만천하스카이워크": "만천하 스카이워크",
    "봉학골산림공원": "봉학골",
    "좌구산자연휴양림": "좌구산 자연휴양림",
    "좌구산천문대": "좌구산",
    "큰바위얼굴조각공원": "큰바위얼굴",
    "정지용문학관": "정지용 문학관",
    "만뢰산 자연생태공원": "만뢰산",
}

COMMON = {"MobileOS": "ETC", "MobileApp": "ColorTrip", "_type": "json"}
SEM = asyncio.Semaphore(5)
MAX_TRIES = 6  # 401 간헐 재시도 포함 (external-apis.md)

KEY, BASE = "", ""


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
    node = data
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
                    print(f"  ! {endpoint} {params} 실패: {e}")
                    return []
                await asyncio.sleep(min(1.2 * attempt, 5.0))
    return []


def norm(s: str) -> str:
    """장소명 매칭용 정규화 — 공백/괄호 안 내용 제거."""
    s = re.sub(r"\(.*?\)", "", s)
    s = re.sub(r"\[.*?\]", "", s)
    return re.sub(r"\s+", "", s)


async def region_pool(client: httpx.AsyncClient, sigungu: str) -> dict[str, dict[str, str]]:
    """지역의 areaBasedList2 후보를 정규화 제목 → {content_id, content_type_id} 맵으로."""
    pool: dict[str, dict[str, str]] = {}
    for ctid in ("12", "14", "28", "39"):
        for it in await get(
            client,
            "areaBasedList2",
            areaCode="33",
            sigunguCode=sigungu,
            contentTypeId=ctid,
            numOfRows="100",
            pageNo="1",
        ):
            title = norm(str(it.get("title", "")))
            content_id = str(it.get("contentid") or "")
            content_type_id = str(it.get("contenttypeid") or "")
            if title and content_id and content_type_id and title not in pool:
                pool[title] = {"content_id": content_id, "content_type_id": content_type_id}
    return pool


def pool_match(pool: dict[str, dict[str, str]], place: str) -> dict[str, str] | None:
    p = norm(place)
    if not p:
        return None
    if p in pool:
        return pool[p]
    # 부분 일치: 후보 제목이 장소명을 포함하거나 그 반대 (가장 긴 제목 우선)
    candidates = [(t, v) for t, v in pool.items() if p in t or t in p]
    if candidates:
        candidates.sort(key=lambda x: len(x[0]), reverse=True)
        return candidates[0][1]
    return None


async def keyword_match(
    client: httpx.AsyncClient, sigungu: str, kname: str, place: str
) -> dict[str, str] | None:
    """키워드 검색 후 주소(addr1)·legacy 코드로 클라이언트 필터 (enrich와 동일한 이유)."""
    keyword = re.sub(r"\(.*?\)", "", place).strip()
    keyword = KEYWORD_ALIAS.get(keyword, keyword)
    items = await get(client, "searchKeyword2", keyword=keyword, numOfRows="30", pageNo="1")
    if not items and " " in keyword:
        items = await get(
            client, "searchKeyword2", keyword=keyword.split()[-1], numOfRows="30", pageNo="1"
        )

    def addr_of(it: dict[str, Any]) -> str:
        return str(it.get("addr1", "") or "")

    in_sigungu = [
        it
        for it in items
        if kname in addr_of(it)
        or (str(it.get("areacode", "")) == "33" and str(it.get("sigungucode", "")) == sigungu)
    ]
    in_chungbuk = [
        it
        for it in items
        if addr_of(it).startswith("충청북도") or str(it.get("areacode", "")) == "33"
    ]
    for it in in_sigungu or in_chungbuk:
        content_id = str(it.get("contentid") or "")
        content_type_id = str(it.get("contenttypeid") or "")
        if content_id and content_type_id:
            return {"content_id": content_id, "content_type_id": content_type_id}
    return None


QUEST_BLOCK = re.compile(r"(  Quest\(\n(?:    .*\n)+?  \),\n)")


def parse_field(block: str, name: str) -> str | None:
    m = re.search(rf"^    {name}: '((?:[^'\\]|\\.)*)',", block, re.M)
    return m.group(1).replace("\\'", "'").replace("\\\\", "\\") if m else None


def is_generated(quest_id: str) -> bool:
    """생성 퀘스트(id 숫자 6 이상) 여부 — 1~5는 수제(desc 유지)."""
    m = re.search(r"(\d+)$", quest_id)
    return bool(m) and int(m.group(1)) >= 6


def strip_stored_tour_data(block: str, generated: bool) -> str:
    """저장된 공사 데이터 제거 — imageUrl(연속 문자열 줄 포함), 생성 퀘스트의 desc."""
    # 값이 같은 줄이든 다음 줄(들여쓰기 8칸)이든 필드 시작부터 ',' 종료까지 걷어낸다
    block = re.sub(r"^    imageUrl:(?:.*,\n|\n(?:^        .*\n)+)", "", block, flags=re.M)
    block = re.sub(r"^    tourContentId: .*\n", "", block, flags=re.M)  # idempotent
    block = re.sub(r"^    tourContentTypeId: .*\n", "", block, flags=re.M)
    if generated:
        block = re.sub(r"^    desc:(?:.*,\n|\n(?:^        .*\n)+)", "", block, flags=re.M)
    return block


def insert_content_id(block: str, content_id: str, content_type_id: str) -> str:
    """place 필드 다음 줄에 tourContentId/tourContentTypeId를 삽입한다."""
    lines = f"    tourContentId: '{content_id}',\n    tourContentTypeId: '{content_type_id}',\n"
    return re.sub(r"(^    place: .*\n)", rf"\g<1>{lines}", block, count=1, flags=re.M)


async def main() -> None:
    global KEY, BASE
    KEY, BASE = load_key()

    src = DART.read_text(encoding="utf-8")
    blocks = QUEST_BLOCK.findall(src)
    if len(blocks) < 200:
        sys.exit(f"퀘스트 블록 파싱 실패(발견 {len(blocks)}개) — 파일 형식을 확인하세요.")

    async with httpx.AsyncClient(timeout=15.0) as client:
        sigungus = await get(client, "areaCode2", areaCode="33", numOfRows="50")
        code_by_name = {s["name"]: str(s["code"]) for s in sigungus}
        missing = [n for n in REGION_NAMES.values() if n not in code_by_name]
        if missing:
            sys.exit(f"시군구 코드 조회 실패: {missing} / 응답: {code_by_name}")

        pools = {
            rid: await region_pool(client, code_by_name[kname])
            for rid, kname in REGION_NAMES.items()
        }

        mapping: dict[str, dict[str, str]] = {}
        stats = {"matched": 0, "miss": 0}
        missed: list[str] = []
        for block in blocks:
            qid = parse_field(block, "id")
            rid = parse_field(block, "region")
            place = parse_field(block, "place")
            if not (qid and rid and place) or rid not in REGION_NAMES:
                continue
            hit = pool_match(pools[rid], place)
            if hit is None:
                hit = await keyword_match(
                    client, code_by_name[REGION_NAMES[rid]], REGION_NAMES[rid], place
                )
            new_block = strip_stored_tour_data(block, is_generated(qid))
            if hit is not None:
                new_block = insert_content_id(new_block, hit["content_id"], hit["content_type_id"])
                mapping[qid] = hit
                stats["matched"] += 1
            else:
                stats["miss"] += 1
                missed.append(f"{rid}/{qid} {place}")
            src = src.replace(block, new_block, 1)

    DART.write_text(src, encoding="utf-8")
    MAPPING_JSON.parent.mkdir(parents=True, exist_ok=True)
    MAPPING_JSON.write_text(
        json.dumps(mapping, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"완료: 매칭 {stats['matched']} / 미매칭 {stats['miss']}")
    if missed:
        print("미매칭 목록(placeholder로 동작):")
        for m in missed:
            print(f"  - {m}")


if __name__ == "__main__":
    asyncio.run(main())
