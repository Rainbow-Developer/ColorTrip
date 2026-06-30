# [구현 수준] 인증/회원 (Auth/Member)

| 항목 | 내용 |
|------|------|
| 상태 | 구현 완료 / PostgreSQL 기반 테스트 통과 |
| 최종 업데이트 | 2026-06-30 |

## 구현 규모 / 단위 분할

- **규모 판단**: 단위로 나눠 구현 — 문서 체계 이관, DB 마이그레이션, auth service, 보호 API dependency, dev-only 검증 페이지, PostgreSQL 테스트가 서로 의존한다.
- **구현 단위**:
  - [x] 1) origin/dev 구조 분석 및 재구성 방향 확정.
  - [x] 2) 기능 스펙과 conventions/readme 문서 동기화.
  - [x] 3) `backend/app/auth/` 도메인 구현.
  - [x] 4) users/refresh_tokens 마이그레이션 추가.
  - [x] 5) PostgreSQL 기반 테스트 작성.
  - [x] 6) auth 보안/동시성 리뷰 보완.
  - [x] 7) root 이전 구현 파일 정리 및 품질 게이트 통과.

## 구현된 항목

- 재구성 방향 확정:
  - origin/dev의 `backend/app/` 도메인 구조를 기준으로 auth/member를 재작성한다.
  - 기존 root `app/`, root `tests/`, root backend용 `pyproject.toml`, root `uv.lock`는 최종 산출물에서 제거한다.
  - 응답 Envelope는 `code/status/message/data`를 따른다.
- backend auth 도메인:
  - `backend/app/auth/`에 모델, 스키마, repository, service, router, dependency, Kakao client, dev-only router를 추가했다.
  - `backend/app/core/security.py`에 access JWT 생성/검증과 refresh token 생성/hash primitive를 추가했다.
  - `backend/app/core/exceptions.py`에 auth 관련 error code를 추가했다.
  - `backend/alembic/versions/d7b712f1a245_add_auth_member_tables.py`로 `users`, `refresh_tokens` 테이블을 추가했다.
  - Refresh token renewal은 row lock으로 rotation race를 막는다.
  - Kakao 로그인은 unique constraint 충돌 시 rollback 후 재시도해 동시 최초 로그인/재가입 요청을 수렴시킨다.
  - Kakao API invalid JSON/shape는 `SOCIAL_AUTH_ERROR` envelope로 변환한다.
  - `local/test` 외 환경은 기본 JWT secret과 dev auth route 노출을 시작 시 거부한다.
- 테스트:
  - `backend/tests/`에 Kakao login, token rotation/logout, `CurrentUser`, 탈퇴/복구/익명화 API 테스트를 추가했다.
  - 테스트 DB는 PostgreSQL `localhost:5433/colortrip_test`를 사용하고, Alembic `upgrade head`로 스키마를 만든다.

## 미구현 / 남은 항목

- 실제 Kakao OAuth 브라우저 수동 검증은 로컬 서버와 Kakao Console redirect 설정이 준비된 상태에서 별도 수행한다.

## 알려진 한계 / TODO

- 30일 보존 이후 hard delete batch는 별도 M3 작업이다.
- Flutter secure storage 연동은 frontend 작업이다.
- 운영 Secret Manager 등록은 별도 인프라 작업이다.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-06-30 | origin/dev 기준 Auth/Member 재구성 스펙 최초 작성 |
| 2026-06-30 | backend auth/member 구현, 마이그레이션, PostgreSQL 테스트 작성, root 이전 구현 정리 |
| 2026-06-30 | refresh rotation race, Kakao login unique race, Kakao invalid response, non-local JWT secret 검증 보완 |
