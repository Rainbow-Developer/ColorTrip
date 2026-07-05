#!/usr/bin/env python3
"""브랜치 네이밍 <type>/<이슈번호>-<설명> 검사.

강제 대상: docs/conventions/scm-collaboration.md
  --mode=claude : Claude Code PreToolUse(Bash). git switch -c / checkout -b / branch <name>의 새 이름 검사.
  --mode=git    : git pre-commit 훅. 현재 브랜치명 검사(보호 브랜치는 예외).

차단: Claude 모드는 exit 2, git 모드는 exit 1.
"""
import json
import shlex
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import _rules  # noqa: E402


def hint(name: str) -> str:
    return (
        f"브랜치 이름 '{name}'이 규칙에 맞지 않습니다.\n"
        "  형식: <type>/<이슈번호>-<설명> 또는 <type>/<이슈번호>\n"
        f"  type: {', '.join(_rules.BRANCH_TYPES)}\n"
        "  예) feature/123-add-login, feat/KAN-123, fix/CT-12-pagination-bug"
    )


def get_mode() -> str:
    for arg in sys.argv[1:]:
        if arg.startswith("--mode="):
            return arg.split("=", 1)[1]
    return "claude"


def extract_new_branch(command: str):
    """새 브랜치를 만드는 명령에서 브랜치 이름을 추출한다. 없으면 None."""
    try:
        tokens = shlex.split(command)
    except ValueError:
        return None
    for i, token in enumerate(tokens):
        if token != "git" or i + 1 >= len(tokens):
            continue
        sub = tokens[i + 1]
        rest = tokens[i + 2:]
        if sub == "switch":
            for flag in ("-c", "-C"):
                if flag in rest:
                    j = rest.index(flag)
                    if j + 1 < len(rest):
                        return rest[j + 1]
        elif sub == "checkout":
            for flag in ("-b", "-B"):
                if flag in rest:
                    j = rest.index(flag)
                    if j + 1 < len(rest):
                        return rest[j + 1]
        elif sub == "branch":
            for arg in rest:
                if not arg.startswith("-"):
                    return arg
    return None


def main() -> None:
    mode = get_mode()

    if mode == "git":
        branch = _rules.current_branch()
        if branch is None or branch in _rules.PROTECTED_BRANCHES:
            sys.exit(0)
        if not _rules.is_valid_branch_name(branch):
            print(f"[branch-name] {hint(branch)}", file=sys.stderr)
            sys.exit(1)
        sys.exit(0)

    # claude 모드
    try:
        data = json.loads(sys.stdin.read())
    except Exception:
        sys.exit(0)
    command = (data.get("tool_input") or {}).get("command", "")
    name = extract_new_branch(command)
    if name is None or name in _rules.PROTECTED_BRANCHES:
        sys.exit(0)
    if not _rules.is_valid_branch_name(name):
        print(f"[branch-name] {hint(name)}", file=sys.stderr)
        sys.exit(2)
    sys.exit(0)


main()
