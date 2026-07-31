"""퀘스트 현장 QR 이미지 생성 스크립트 — docs/specs/050-quest-verification/

서명 페이로드(colortrip:quest:{id}:{HMAC-SHA256 16자})를 만들어 PNG로 저장한다.
서명 키는 backend/.env의 QR_SECRET_KEY(미설정 시 JWT_SECRET_KEY 파생)를 쓰므로,
서버와 같은 .env로 실행해야 서버 검증을 통과하는 QR이 나온다.

실행 (dev 의존성 필요: uv sync --group dev):
    cd backend && uv run python scripts/generate_quest_qr.py dy3 cj4 ...
    # 인자 없으면 frontend/lib/data/static/quests_data.dart의 verify: 'qr' 퀘스트 전부

출력: backend/qr_output/{id}.png (+ 페이로드 stdout, qr_output/은 .gitignore 대상)
"""

import argparse
import re
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
QUESTS_DART = BACKEND.parent / "frontend" / "lib" / "data" / "static" / "quests_data.dart"
OUTPUT_DIR = BACKEND / "qr_output"

# scripts/를 직접 실행해도 app 패키지를 찾도록 backend를 경로에 추가한다.
sys.path.insert(0, str(BACKEND))

from app.verifications.service import sign_quest_payload  # noqa: E402


def collect_static_qr_quest_ids() -> list[str]:
    """quests_data.dart에서 verify: 'qr'인 퀘스트 id를 수집한다 (id → verify 순서 전제)."""
    if not QUESTS_DART.exists():
        return []
    source = QUESTS_DART.read_text(encoding="utf-8")
    ids: list[str] = []
    current_id: str | None = None
    for match in re.finditer(r"\b(id|verify):\s*'([^']*)'", source):
        key, value = match.group(1), match.group(2)
        if key == "id":
            current_id = value
        elif value == "qr" and current_id:
            ids.append(current_id)
            current_id = None
    return ids


def main() -> None:
    parser = argparse.ArgumentParser(description="퀘스트 QR PNG 생성 (서명 페이로드)")
    parser.add_argument(
        "quest_ids",
        nargs="*",
        help="퀘스트 id 목록 (생략 시 frontend 정적 데이터의 verify: 'qr' 퀘스트 전부)",
    )
    args = parser.parse_args()

    quest_ids: list[str] = args.quest_ids or collect_static_qr_quest_ids()
    if not quest_ids:
        sys.exit(
            "verify: 'qr' 퀘스트를 찾지 못했습니다 — 정적 데이터의 QR 전환(045 보강 스크립트)이 "
            "아직일 수 있습니다. 퀘스트 id를 인자로 직접 넘겨주세요.\n"
            f"  (탐색 파일: {QUESTS_DART})"
        )

    try:
        import qrcode
    except ImportError:
        sys.exit("qrcode 패키지가 없습니다 — `uv sync --group dev` 후 다시 실행하세요.")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for quest_id in quest_ids:
        payload = sign_quest_payload(quest_id)
        path = OUTPUT_DIR / f"{quest_id}.png"
        qrcode.make(payload).save(path)
        print(f"{quest_id}: {payload} -> {path.relative_to(BACKEND)}")
    print(f"완료 — QR {len(quest_ids)}개를 {OUTPUT_DIR}에 생성했습니다.")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[union-attr]
    main()
