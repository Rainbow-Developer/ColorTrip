#!/usr/bin/env python3
"""보호 브랜치(dev/main) 직접 커밋·푸시 차단.

강제 대상: docs/conventions/scm-collaboration.md
  --mode=claude : Claude Code PreToolUse(Bash). 명령이 git commit/push이고 현재 브랜치가 보호 브랜치면 차단.
  --mode=git    : git pre-commit / pre-push 훅. 현재 브랜치가 보호 브랜치면 차단.

차단: Claude 모드는 exit 2, git 모드는 exit 1.
"""
import json
import shlex
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import _rules  # noqa: E402


def hint(branch: str) -> str:
    return (
        f"'{branch}'는 보호 브랜치입니다. 직접 커밋·푸시할 수 없습니다.\n"
        "  새 브랜치에서 작업하세요:  git switch -c <type>/<이슈번호>-<설명>\n"
        "  (예: git switch -c feat/123-add-login)"
    )


def get_mode() -> str:
    for arg in sys.argv[1:]:
        if arg.startswith("--mode="):
            return arg.split("=", 1)[1]
    return "claude"


def is_commit_or_push(command: str) -> bool:
    try:
        tokens = shlex.split(command)
    except ValueError:
        return False
    for i, token in enumerate(tokens):
        if token == "git" and i + 1 < len(tokens) and tokens[i + 1] in ("commit", "push"):
            return True
    return False


def main() -> None:
    mode = get_mode()

    if mode == "git":
        branch = _rules.current_branch()
        if branch in _rules.PROTECTED_BRANCHES:
            print(f"[protected-branch] {hint(branch)}", file=sys.stderr)
            sys.exit(1)
        sys.exit(0)

    # claude 모드
    try:
        data = json.loads(sys.stdin.read())
    except Exception:
        sys.exit(0)
    command = (data.get("tool_input") or {}).get("command", "")
    if not is_commit_or_push(command):
        sys.exit(0)
    branch = _rules.current_branch(data.get("cwd"))
    if branch in _rules.PROTECTED_BRANCHES:
        print(f"[protected-branch] {hint(branch)}", file=sys.stderr)
        sys.exit(2)
    sys.exit(0)


main()
