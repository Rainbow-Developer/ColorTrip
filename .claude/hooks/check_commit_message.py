#!/usr/bin/env python3
"""커밋 메시지 Conventional Commits 검사.

강제 대상: docs/conventions/scm-collaboration.md
  --mode=claude : Claude Code PreToolUse(Bash). stdin JSON의 명령에서 `git commit -m` 추출.
  --mode=git    : git commit-msg 훅. 마지막 positional 인자가 커밋 메시지 파일 경로.

차단: Claude 모드는 exit 2(stderr를 에이전트에 전달), git 모드는 exit 1.
"""
import json
import shlex
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import _rules  # noqa: E402

HINT = (
    "커밋 메시지는 Conventional Commits 형식이어야 합니다.\n"
    "  형식: <type>(scope)?: <설명>\n"
    f"  type: {', '.join(_rules.COMMIT_TYPES)}\n"
    "  예) feat: 카카오 로그인 추가 / fix(api): 페이지네이션 오류 수정"
)


def get_mode() -> str:
    for arg in sys.argv[1:]:
        if arg.startswith("--mode="):
            return arg.split("=", 1)[1]
    return "claude"


def extract_commit_message(command: str):
    """명령 문자열에서 git commit 메시지를 추출한다.
    - 커밋 명령이 아니면 None
    - 커밋이지만 -m 없음(에디터 커밋)이면 "" (검사 불가 → 통과)
    """
    try:
        tokens = shlex.split(command)
    except ValueError:
        return None

    saw_commit = False
    messages = []
    i = 0
    while i < len(tokens):
        token = tokens[i]
        if token == "git" and i + 1 < len(tokens) and tokens[i + 1] == "commit":
            saw_commit = True
        if saw_commit:
            if token in ("-m", "--message") and i + 1 < len(tokens):
                messages.append(tokens[i + 1])
                i += 2
                continue
            if token.startswith("--message="):
                messages.append(token.split("=", 1)[1])
            elif token.startswith("-m") and len(token) > 2:
                messages.append(token[2:])
        i += 1

    if not saw_commit:
        return None
    if not messages:
        return ""
    return messages[0]


def main() -> None:
    mode = get_mode()

    if mode == "git":
        files = [a for a in sys.argv[1:] if not a.startswith("--")]
        if not files:
            sys.exit(0)
        message = Path(files[0]).read_text(encoding="utf-8")
        if not _rules.is_valid_commit_message(message):
            print(f"[commit-msg] 커밋 메시지 형식 위반\n{HINT}", file=sys.stderr)
            sys.exit(1)
        sys.exit(0)

    # claude 모드
    try:
        data = json.loads(sys.stdin.read())
    except Exception:
        sys.exit(0)
    command = (data.get("tool_input") or {}).get("command", "")
    message = extract_commit_message(command)
    if message is None or message == "":
        sys.exit(0)
    if not _rules.is_valid_commit_message(message):
        print(f"[commit-msg] 커밋 메시지 형식 위반: {message!r}\n{HINT}", file=sys.stderr)
        sys.exit(2)
    sys.exit(0)


main()
