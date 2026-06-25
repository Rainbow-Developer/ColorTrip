# [컨벤션] 형상 관리 & 협업

> **범위**: 형상 관리 호스팅·레포 구조·브랜치·커밋·PR·이슈 트래킹.
> **변경 시**: 이 문서를 단일 출처로 갱신합니다 ([AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 참고).

## 결정 사항

| 항목 | 결정 | 비고 |
|------|------|------|
| 형상 관리 호스팅 | GitHub | |
| 레포 구조 | 모노레포 (백엔드+프론트엔드 한 저장소) | |
| 브랜치 전략 | main / dev (2개 통합 브랜치) | |
| 브랜치 네이밍 | `type/이슈번호-설명` | |
| 커밋 메시지 컨벤션 | Conventional Commits (feat:, fix: 등) | |
| PR 병합 방식 | Squash and merge | |
| PR 리뷰 규칙 | 최소 1명 승인 필수 | |
| 이슈 트래킹 / 작업 관리 | Jira | |

## 규칙 / 적용

- `[강제]` dev/main 브랜치 직접 커밋·푸시 금지 — HOOK `.claude/hooks/check_protected_branch.py`(Claude Code) + git pre-push 훅.
- `[강제]` 브랜치 네이밍 `type/이슈번호-설명` — HOOK `.claude/hooks/check_branch_name.py`.
- `[강제]` 커밋 메시지 Conventional Commits (feat:, fix: 등) — HOOK `.claude/hooks/check_commit_message.py` + git commit-msg(pre-commit).
- PR은 `dev` 브랜치로 올리고, Squash and merge로 병합하며, 최소 1명 승인이 필요합니다.
- PR 작성 절차는 `dev-pr` 스킬을 사용합니다.
- 올바른 브랜치·커밋 절차는 `commit` 스킬(`.claude/skills/commit/`)을 참고합니다.

## 관련 문서

- [코드 품질 & 컨벤션](./code-quality.md)
- [문서화 & 협업 도구](./docs-tools.md)
- [AGENT_GUIDE](../AGENT_GUIDE.md)
