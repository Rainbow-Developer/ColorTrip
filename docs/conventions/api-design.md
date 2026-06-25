# [컨벤션] API 설계 & 응답 형식

> **범위**: API 아키텍처·응답 envelope·에러 코드·URL 컨벤션·페이지네이션·날짜 포맷·문서화
> **변경 시**: 이 문서를 단일 출처로 갱신합니다 ([AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 참고).

## 결정 사항

| 항목 | 결정 | 비고 |
|------|------|------|
| 아키텍처 | 이후 결정 | 미정 — 다음 결정 대상 |
| 응답 Envelope | `code / status / message / data` | 팀 상단 확정 메모에는 code/message/data로 적혔으나, 본 영역에서 status를 포함한 code/status/message/data를 단일 출처로 확정 |
| 에러 코드 체계 | HTTP status + 내부 코드 | 예: SUCCESS / NOT_FOUND_ERROR |
| URL 컨벤션 | `/api/v1` + 복수형 명사 (kebab-case) | |
| 페이지네이션 | Offset 방식 (page / size) | |
| 날짜 / 시간 응답 포맷 | ISO 8601 (+09:00) | |
| API 문서화 | Swagger 자동 생성 + Notion 수동 링크 | |

## 규칙 / 적용

- 모든 응답은 envelope(`code / status / message / data`)로 감싼다.
- URL은 `/api/v1` 하위에 kebab-case 복수형 명사로 작성한다.
- 에러 코드는 HTTP status와 내부 코드(예: SUCCESS / NOT_FOUND_ERROR)를 함께 사용한다.
- 페이지네이션은 Offset 방식으로 page / size 파라미터를 사용한다.
- 날짜 / 시간 응답은 ISO 8601 (+09:00) 포맷을 따른다.
- API 명세 도구는 [문서화 도구](./docs-tools.md)를 따른다.

## 관련 문서

- [문서화 도구](./docs-tools.md)
- [데이터베이스 & 모델링](./database.md)
