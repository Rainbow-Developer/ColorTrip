"""정적 퀘스트/지역 데이터에 TourAPI 이미지·좌표를 보강하는 스크립트.

- quests_data.dart: 각 Quest에 imageUrl(firstimage)·lat(mapy)·lng(mapx)를 삽입/갱신한다.
  매칭은 areaBasedList2(지역×관광지12·문화14·레포츠28·음식39) 제목 → 실패 시
  searchKeyword2(시군구 한정)로 보충한다. 미매칭은 필드 없이 둔다(placeholder 폴백).
- regions_data.dart: 지역 대표 명소(curated)의 이미지를 Region.imageUrl로 삽입한다.
- QR 인증 전환: 지역당 1개(수제 food 우선, 없으면 수제 photo)를 verify 'qr'로 바꾸고
  conditions를 QR 안내로 교체한다 (docs/specs/050-quest-verification).

재실행 가능(idempotent): 이미 삽입된 imageUrl/lat/lng는 값을 갱신하고,
이미 'qr'인 퀘스트는 다시 전환하지 않는다.

실행 (backend/.env의 TOUR_API_KEY 필요):
    cd backend && uv run python scripts/enrich_frontend_quests.py

스펙: docs/specs/045-quest-region-images/ · TourAPI 규약: docs/conventions/external-apis.md
"""

import asyncio
import re
import sys
from pathlib import Path
from typing import Any

import httpx

REPO = Path(__file__).resolve().parents[2]
ENV = REPO / "backend" / ".env"
QUESTS_DART = REPO / "frontend" / "lib" / "data" / "static" / "quests_data.dart"
REGIONS_DART = REPO / "frontend" / "lib" / "data" / "static" / "regions_data.dart"

# region id ↔ TourAPI 시군구명 (generate_frontend_quests.py와 동일)
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

# 지역 대표 이미지용 명소 키워드 (수제 퀘스트 1~5번의 대표 장소 기준)
REGION_LANDMARK = {
    "danyang": "도담삼봉",
    "cheongju": "청남대",
    "boeun": "법주사",
    "chungju": "탄금대",
    "jecheon": "의림지",
    "eumseong": "봉학골",
    "jincheon": "농다리",
    "jeungpyeong": "좌구산 자연휴양림",
    "goesan": "산막이옛길",
    "okcheon": "부소담악",
    "yeongdong": "월류봉",
}

# 키워드 검색 별칭 — 정적 데이터의 붙여쓴 장소명과 TourAPI 표기(띄어쓰기)가 달라
# 검색이 0건이 되는 항목들 (재실행 리포트 기준 수동 관리)
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
                    print(f"  ! {endpoint} {params} 실패: {e}")
                    return []
                await asyncio.sleep(min(1.2 * attempt, 5.0))
    return []


def norm(s: str) -> str:
    """장소명 매칭용 정규화 — 공백/괄호 안 내용 제거."""
    s = re.sub(r"\(.*?\)", "", s)
    s = re.sub(r"\[.*?\]", "", s)
    return re.sub(r"\s+", "", s)


def https(url: str) -> str:
    """Android/iOS 정책상 가능하면 https로 (TourAPI CDN은 https 지원)."""
    return url.replace("http://", "https://", 1) if url.startswith("http://") else url


class Hit:
    def __init__(self, item: dict[str, Any]) -> None:
        self.image = https(str(item.get("firstimage") or "").strip())
        self.lat = str(item.get("mapy") or "").strip()
        self.lng = str(item.get("mapx") or "").strip()

    @property
    def has_any(self) -> bool:
        return bool(self.image or (self.lat and self.lng))


async def region_pool(client: httpx.AsyncClient, sigungu: str) -> dict[str, Hit]:
    """지역의 areaBasedList2 후보를 정규화 제목 → Hit 맵으로."""
    pool: dict[str, Hit] = {}
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
            if not title:
                continue
            hit = Hit(it)
            if not hit.has_any:
                continue
            # 이미지 있는 항목 우선 유지
            if title not in pool or (hit.image and not pool[title].image):
                pool[title] = hit
    return pool


def pool_match(pool: dict[str, Hit], place: str) -> Hit | None:
    p = norm(place)
    if not p:
        return None
    if p in pool:
        return pool[p]
    # 부분 일치: 후보 제목이 장소명을 포함하거나 그 반대 (가장 긴 제목 우선)
    candidates = [(t, h) for t, h in pool.items() if p in t or t in p]
    if candidates:
        candidates.sort(key=lambda x: (bool(x[1].image), len(x[0])), reverse=True)
        return candidates[0][1]
    return None


async def keyword_match(
    client: httpx.AsyncClient, sigungu: str, kname: str, place: str
) -> Hit | None:
    """키워드 검색 후 주소(addr1)·legacy 코드로 클라이언트 필터.

    KorService2의 searchKeyword2는 areaCode/sigunguCode 파라미터를 주면 0건을
    반환하고(법정동 코드 전환 영향), 응답의 legacy areacode/sigungucode도 빈 값인
    항목이 많다 — addr1("충청북도 보은군 …")과 legacy 코드를 함께 보고 걸러낸다.
    """
    keyword = re.sub(r"\(.*?\)", "", place).strip()  # 괄호 별칭 제거
    keyword = KEYWORD_ALIAS.get(keyword, keyword)
    items = await get(client, "searchKeyword2", keyword=keyword, numOfRows="30", pageNo="1")
    if not items and " " in keyword:  # "속리산 법주사" → "법주사" 재시도
        items = await get(
            client, "searchKeyword2", keyword=keyword.split()[-1], numOfRows="30", pageNo="1"
        )

    def addr_of(it: dict[str, Any]) -> str:
        return str(it.get("addr1", "") or "")

    # 1순위: 주소가 해당 시·군 / 2순위: legacy 코드 일치 / 3순위: 충북 주소
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
    hits = [Hit(it) for it in (in_sigungu or in_chungbuk)]
    hits = [h for h in hits if h.has_any]
    if not hits:
        return None
    hits.sort(key=lambda h: bool(h.image), reverse=True)
    return hits[0]


QUEST_BLOCK = re.compile(r"(  Quest\(\n(?:    .*\n)+?  \),\n)")
FIELD = re.compile(r"^    (\w+): (.*?),?$", re.M)


def parse_field(block: str, name: str) -> str | None:
    m = re.search(rf"^    {name}: '((?:[^'\\]|\\.)*)',", block, re.M)
    return m.group(1).replace("\\'", "'").replace("\\\\", "\\") if m else None


def strip_enrich_fields(block: str) -> str:
    """기존 삽입분(imageUrl/lat/lng) 제거 — idempotent 갱신용."""
    return re.sub(r"^    (?:imageUrl|lat|lng): .*\n", "", block, flags=re.M)


def insert_fields(block: str, lines: list[str]) -> str:
    """닫는 '  ),' 직전에 필드 라인들을 삽입한다."""
    if not lines:
        return block
    return block.replace("\n  ),\n", "\n" + "".join(lines) + "  ),\n", 1)


def to_qr(block: str, place: str) -> str:
    block = block.replace("    verify: 'photo',\n", "    verify: 'qr',\n", 1)
    esc = place.replace("\\", "\\\\").replace("'", "\\'")
    block = re.sub(
        r"^    conditions: \[.*\],\n",
        f"    conditions: ['{esc} 현장 부착 QR 코드 스캔'],\n",
        block,
        count=1,
        flags=re.M,
    )
    return block


async def main() -> None:
    global KEY, BASE
    KEY, BASE = load_key()

    src = QUESTS_DART.read_text(encoding="utf-8")
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

        stats = {"image": 0, "coord": 0, "miss": 0, "qr": 0}
        gps_without_coord: list[str] = []
        qr_done: set[str] = set()
        # 이미 qr인 지역은 전환 스킵
        for block in blocks:
            if "verify: 'qr'" in block:
                rid = parse_field(block, "region")
                if rid:
                    qr_done.add(rid)

        # 지역별 QR 전환 대상 선정: 수제(1~5) food 우선 → 없으면 첫 수제 photo
        qr_target: dict[str, tuple[str, str]] = {}  # rid -> (qid, qtype)
        for block in blocks:
            qid = parse_field(block, "id")
            rid = parse_field(block, "region")
            qtype = parse_field(block, "type") or ""
            verify = parse_field(block, "verify")
            if not (qid and rid) or rid in qr_done or verify != "photo":
                continue
            if not re.match(r"^[a-z]{2}[1-5]$", qid):  # 수제(1~5번)만
                continue
            cur = qr_target.get(rid)
            if cur is None or (qtype == "food" and cur[1] != "food"):
                qr_target[rid] = (qid, qtype)

        new_src = src
        for block in blocks:
            qid = parse_field(block, "id")
            rid = parse_field(block, "region")
            place = parse_field(block, "place")
            verify = parse_field(block, "verify")
            if not (qid and rid and place):
                continue

            hit = pool_match(pools.get(rid, {}), place)
            if hit is None:
                kname = REGION_NAMES[rid]
                hit = await keyword_match(client, code_by_name[kname], kname, place)

            updated = strip_enrich_fields(block)
            lines: list[str] = []
            if hit and hit.image:
                esc = hit.image.replace("\\", "\\\\").replace("'", "\\'")
                lines.append(f"    imageUrl: '{esc}',\n")
                stats["image"] += 1
            if hit and hit.lat and hit.lng:
                lines.append(f"    lat: {hit.lat},\n")
                lines.append(f"    lng: {hit.lng},\n")
                stats["coord"] += 1
            if not lines:
                stats["miss"] += 1
                print(f"  - 미매칭: {qid} ({place})")
            updated = insert_fields(updated, lines)

            if qr_target.get(rid, ("", ""))[0] == qid:
                updated = to_qr(updated, place)
                stats["qr"] += 1

            if verify == "gps" and not (hit and hit.lat and hit.lng):
                gps_without_coord.append(f"{qid} ({place})")

            if updated != block:
                new_src = new_src.replace(block, updated, 1)

        QUESTS_DART.write_text(new_src, encoding="utf-8", newline="\n")
        print(
            f"quests_data.dart 갱신 — 이미지 {stats['image']}개, 좌표 {stats['coord']}개, "
            f"미매칭 {stats['miss']}개, QR 전환 {stats['qr']}개"
        )
        if gps_without_coord:
            print(f"  ! 좌표 없는 gps 퀘스트 {len(gps_without_coord)}개: {gps_without_coord}")

        # ---- 지역 대표 이미지 ----
        rsrc = REGIONS_DART.read_text(encoding="utf-8")
        region_hits = 0
        for rid, kname in REGION_NAMES.items():
            landmark = REGION_LANDMARK[rid]
            hit = pool_match(pools[rid], landmark)
            if hit is None or not hit.image:
                hit = await keyword_match(client, code_by_name[kname], kname, landmark)
            if hit is None or not hit.image:
                print(f"  - 지역 대표 이미지 미매칭: {rid} ({landmark})")
                continue
            esc = hit.image.replace("\\", "\\\\").replace("'", "\\'")
            # 해당 Region 블록의 path 라인 뒤(닫는 "  )," 직전)에 imageUrl 삽입/갱신
            block_re = re.compile(
                rf"(  Region\(\n    id: '{rid}',\n(?:.*\n)+?  \),\n)",
            )
            m = block_re.search(rsrc)
            if not m:
                print(f"  ! Region 블록 파싱 실패: {rid}")
                continue
            block = m.group(1)
            updated = re.sub(r"^    imageUrl: .*\n", "", block, flags=re.M)
            updated = updated.replace("\n  ),\n", f"\n    imageUrl: '{esc}',\n  ),\n", 1)
            rsrc = rsrc.replace(block, updated, 1)
            region_hits += 1
        REGIONS_DART.write_text(rsrc, encoding="utf-8", newline="\n")
        print(f"regions_data.dart 갱신 — 대표 이미지 {region_hits}/11")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[union-attr]
    asyncio.run(main())
