# [컨벤션] 코드 품질 & 컨벤션

> **범위**: 린트·포맷·타입체크·커밋 전 자동 검사·테스트 정책.
> **변경 시**: 이 문서를 단일 출처로 갱신합니다 ([AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 참고).

## 결정 사항

| 항목 | 결정 | 비고 |
|------|------|------|
| Python 린트/포맷 | Ruff (린트 + 포맷) | |
| Python 타입 체크 | Pyright | |
| 프론트엔드 린트/포맷 | dart analyze + dart format | |
| 커밋 전 자동 검사 | pre-commit 프레임워크 (백엔드·프론트엔드 공통) | 프론트엔드는 dart format/analyze 훅 |
| 테스트 정책 | 초기엔 생략 | |
| 테스트 도구 | pytest(백엔드), flutter_test(프론트엔드) | |

## 규칙 / 적용

- `[강제]` 커밋 전 자동 검사 — git hook은 **pre-commit 프레임워크 한 곳**으로 일원화합니다(`.pre-commit-config.yaml`). 백엔드는 Ruff·Pyright, 프론트엔드는 `dart format`·`flutter analyze` 훅을 등록합니다(별도 husky 미사용 — 단일 hook 관리자 유지).
- 테스트는 초기에는 생략하나, 도구는 pytest(백엔드)·flutter_test(프론트엔드)로 정합니다(추후 도입).

## 관련 문서

- [형상 관리 & 협업](./scm-collaboration.md)
- [AGENT_GUIDE](../AGENT_GUIDE.md)
