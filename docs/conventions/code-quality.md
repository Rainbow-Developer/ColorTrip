# [컨벤션] 코드 품질 & 컨벤션

> **범위**: 린트·포맷·타입체크·커밋 전 자동 검사·테스트 정책.
> **변경 시**: 이 문서를 단일 출처로 갱신합니다 ([AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 참고).

## 결정 사항

| 항목 | 결정 | 비고 |
|------|------|------|
| Python 린트/포맷 | Ruff (린트 + 포맷) | |
| Python 타입 체크 | Pyright | |
| 프론트엔드 린트/포맷 | dart analyze + dart format | |
| 커밋 전 자동 검사 | pre-commit(백엔드) + husky·lint-staged(프론트엔드) | |
| 테스트 정책 | 초기엔 생략 | |
| 테스트 도구 | pytest(백엔드), flutter_test(프론트엔드) | |

## 규칙 / 적용

- `[강제]` 커밋 전 자동 검사 — git hook (pre-commit 프레임워크 / husky·lint-staged). `.pre-commit-config.yaml`에 Ruff·Pyright 등을 등록합니다.
- 테스트는 초기에는 생략하나, 도구는 pytest(백엔드)·flutter_test(프론트엔드)로 정합니다(추후 도입).

## 관련 문서

- [형상 관리 & 협업](./scm-collaboration.md)
- [AGENT_GUIDE](../AGENT_GUIDE.md)
