# [컨벤션] 데이터베이스 & 모델링

> **범위**: DBMS·네이밍·PK·타임스탬프·Soft Delete·시간 기준·시드
> **변경 시**: 이 문서를 단일 출처로 갱신합니다 ([AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 참고).

## 결정 사항

| 항목 | 결정 | 비고 |
|------|------|------|
| DBMS | PostgreSQL | |
| 테이블 / 컬럼 네이밍 | snake_case | |
| PK 전략 | UUID v7 | |
| 공통 타임스탬프(감사 컬럼) | created_at / updated_at / deleted_at (Soft Delete) | |
| 탈퇴 시 보존 기간(Soft Delete) | 30일 | |
| 탈퇴 계정 복구 유예 | 7일 | 동일 Kakao 계정 재로그인 시 복구 |
| 시간 저장 기준 | KST 저장 | |
| DB 클라이언트(GUI) | 각자 자유 선택 | |
| 시드 / 더미 데이터 | 마이그레이션에 포함 | |

## 규칙 / 적용

- 모든 테이블은 created_at / updated_at / deleted_at 감사 컬럼을 보유한다.
- 삭제는 물리 삭제가 아닌 deleted_at을 채우는 Soft Delete로 처리하며, 보존 기간은 30일이다.
- 회원 탈퇴는 7일 복구 유예와 30일 보존 정책을 분리한다. 7일 이내 동일 Kakao 계정 재로그인은 기존 user를 복구하고, 7일 이후 동일 Kakao 계정 재로그인은 기존 user를 익명화한 뒤 새 user를 생성한다.
- PK는 UUID v7로 생성한다.
- 시간은 KST 기준으로 저장한다.
- 시드 / 더미 데이터는 마이그레이션에 포함한다. 마이그레이션 도구는 [백엔드 스택](./backend.md)을 따른다.

## 관련 문서

- [백엔드 스택](./backend.md)
- [API 설계 & 응답 형식](./api-design.md)
