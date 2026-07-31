# [컨벤션] 데이터베이스 & 모델링

> **범위**: DBMS·네이밍·PK·타임스탬프·Soft Delete·시간 기준·시드
> **변경 시**: 이 문서를 단일 출처로 갱신합니다 ([AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 참고).

## 결정 사항

| 항목 | 결정 | 비고 |
|------|------|------|
| DBMS | PostgreSQL | |
| 테이블 / 컬럼 네이밍 | snake_case | |
| PK 전략 | UUID v7 | |
| 공통 타임스탬프(감사 컬럼) | created_at / updated_at / deleted_at (Soft Delete) | 탈퇴 시 물리 삭제하는 `user_consents` 예외는 아래 규칙 참고 |
| 일반 Soft Delete 보존 기간 | 30일 | 회원 인증 PII의 035 즉시 익명화 정책과 별개 |
| 이전 회원 탈퇴 구현(005) | 7일 복구 유예 | [005-auth-member](../specs/005-auth-member/) 이전 구현 기록 |
| 현재 탈퇴 정책(035) | 인증 PII 즉시 익명화·복구 없음, 도메인 기록 보존 | 상세 SOT: [auth-security](./auth-security.md) |
| 시간 저장 기준 | KST 저장 | |
| DB 클라이언트(GUI) | 각자 자유 선택 | |
| 시드 / 더미 데이터 | 마이그레이션에 포함 | |

## 규칙 / 적용

- 탈퇴 시 물리 삭제하는 `user_consents` 예외를 제외한 모든 테이블은 created_at / updated_at / deleted_at 감사 컬럼을 보유한다. `user_consents`는 created_at / updated_at을 보유한다.
- 일반 도메인 삭제는 물리 삭제가 아닌 deleted_at을 채우는 Soft Delete를 기본으로 하며 보존 기간은 30일이다.
- 회원 탈퇴 시 인증 PII를 즉시 익명화하고 복구를 제공하지 않으며, 도메인 기록은 익명화된 user에 연결해 보존한다.
- 회원 탈퇴의 PII 제거 범위, Kakao unlink 순서, token·consent 처리는 [인증 & 보안 · 개인정보](./auth-security.md)를 단일 출처로 따른다.
- `user_consents`는 탈퇴 시 개인정보 삭제 요구에 따라 물리 삭제하는 명시적 예외다. 그 외 일반 도메인 테이블의 soft-delete·30일 보존 규칙은 유지한다.
- PK는 UUID v7로 생성한다.
- 시간은 KST 기준으로 저장한다.
- 시드 / 더미 데이터는 마이그레이션에 포함한다. 마이그레이션 도구는 [백엔드 스택](./backend.md)을 따른다.

## 관련 문서

- [백엔드 스택](./backend.md)
- [API 설계 & 응답 형식](./api-design.md)
