#!/usr/bin/env python3
"""세션 시작 시 ColorTrip 핵심 작업 지침을 컨텍스트로 주입한다.

Claude Code SessionStart 훅. stdout으로 출력한 내용이 세션 컨텍스트에 추가된다.
상세 지침의 단일 출처는 docs/AGENT_GUIDE.md 이며, 여기서는 핵심만 환기한다.
"""
import sys

CONTEXT = """\
[ColorTrip 작업 지침 리마인드] 상세: docs/AGENT_GUIDE.md
- 작업 전 docs/AGENT_GUIDE.md와 해당 영역 docs/conventions/ 문서를 먼저 확인한다.
- 기능 추가·리팩토링은 '문서 먼저 → 사용자 컨펌 → 구현' 순서. 문서 변경은 doc-update 스킬.
- 기술·규약 결정의 단일 출처는 docs/conventions/. 중복 서술 금지, 링크로 참조한다.
- dev/main 직접 커밋·푸시 금지. 새 브랜치는 <type>/<이슈번호>-<설명> (예: feat/123-add-login).
- 커밋 메시지는 Conventional Commits(feat:, fix: ...). PR은 dev로 (dev-pr 스킬). 커밋 절차는 commit 스킬.
"""


def main() -> None:
    try:
        sys.stdin.read()
    except Exception:
        pass
    print(CONTEXT)
    sys.exit(0)


main()
