"""ColorTrip 커밋·브랜치 규약 검사 로직 (단일 출처).

규약 값(보호 브랜치, 커밋 타입, 브랜치/커밋 형식)의 권위 출처는
docs/conventions/scm-collaboration.md 이며, 이 모듈은 그 규약을 코드로 옮긴 것이다.
Claude Code hooks와 git hooks(check_*.py)가 이 모듈을 공유한다.
표준 라이브러리만 사용한다(외부 의존 없음).
"""
import re
import subprocess

# dev/main 직접 커밋·푸시 금지
PROTECTED_BRANCHES = {"main", "dev"}

# Conventional Commits 타입 (커밋 메시지용)
COMMIT_TYPES = (
    "feat", "fix", "docs", "style", "refactor",
    "perf", "test", "build", "ci", "chore", "revert",
)

# 브랜치 명명용 타입 (feature 허용)
BRANCH_TYPES = (
    "feature", "feat", "fix", "docs", "style", "refactor",
    "perf", "test", "build", "ci", "chore", "revert",
)

_COMMIT_TYPES_JOINED = "|".join(COMMIT_TYPES)
_BRANCH_TYPES_JOINED = "|".join(BRANCH_TYPES)

# <type>(scope)?!?: <설명>
_COMMIT_RE = re.compile(rf"^({_COMMIT_TYPES_JOINED})(\([^)]+\))?!?: .+")

# <type>/<이슈번호>-<설명> 또는 <type>/<이슈번호> (이슈번호: 숫자 또는 Jira 키 PROJ-123)
_BRANCH_RE = re.compile(rf"^({_BRANCH_TYPES_JOINED})/([A-Z]+-)?\d+(-[a-z0-9._-]+)?$")


def is_valid_commit_message(message: str) -> bool:
    """커밋 메시지 첫 줄이 Conventional Commits 형식인지."""
    stripped = message.strip()
    if not stripped:
        return False
    first_line = stripped.splitlines()[0]
    return bool(_COMMIT_RE.match(first_line))


def is_valid_branch_name(name: str) -> bool:
    """브랜치 이름이 <type>/<이슈번호>-<설명> 형식인지."""
    return bool(_BRANCH_RE.match(name))


def current_branch(cwd=None):
    """현재 git 브랜치명. 조회 실패 시 None."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=cwd, capture_output=True, text=True, check=True,
        )
        return result.stdout.strip()
    except Exception:
        return None
