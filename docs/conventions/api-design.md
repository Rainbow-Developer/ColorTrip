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

- **URI 자원 명명**: 복수형 명사를 사용하고, 단어 구분은 하이픈(`-`, kebab-case)을 사용합니다.
  - 예시: `/api/v1/user-profiles`
- **에러 응답 규격**: 에러 발생 시에도 정상 응답과 일관되게 공통 Envelope(`code / status / message / data`) 구조를 사용하며, `data` 필드는 `null`로 반환합니다.
  ```json
  {
      "code": "NOT_FOUND_ERROR",
      "status": 404,
      "message": "대상을 찾을 수 없습니다.",
      "data": null
  }
  ```
  FastAPI 기본 `HTTPException` 및 `RequestValidationError` 등도 전역 예외 핸들러(`app/core/exceptions.py`)를 통해 이 공통 에러 Envelope 규격으로 일괄 변환됩니다.
- **정상 응답 Envelope**: 정상 응답의 경우 모든 결과를 envelope(`code / status / message / data`)로 감싸서 반환합니다.
- **페이지네이션**: Offset 방식으로 `page` / `size` 파라미터를 사용합니다.
- **날짜 / 시간 응답**: ISO 8601 (`+09:00`, 한국 표준시 KST) 포맷을 사용합니다.
- **API 명세 도구**: [문서화 도구](./docs-tools.md)를 따르며, Swagger 자동 생성 기능을 적극 활용합니다.

## 관련 문서

- [문서화 도구](./docs-tools.md)
- [데이터베이스 & 모델링](./database.md)
