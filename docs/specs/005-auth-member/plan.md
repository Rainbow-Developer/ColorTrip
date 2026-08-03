# [계획] 인증/회원 (Auth/Member)

> **이전 구현 기록:** 이 문서의 7일 복구·30일 보존 계획은 현재 정책이 아니다.
> [035 Kakao 통합 인증](../035-kakao-auth-integration/)이 즉시 익명화·복구 없음 정책과
> Flutter SDK 통합을 대체 정의한다. 아래 내용은 최초 백엔드 기반의 의사결정 이력으로 보존한다.

| 항목 | 내용 |
|------|------|
| 기능명 | 인증/회원 (Auth/Member) |
| Spec 폴더 | `docs/specs/005-auth-member/` |
| 영역 | backend |
| 작성자 | Auth/Member 담당 |
| 작성일 | 2026-06-30 |
| 상태 | 이전 구현 기록 / 현재 정책은 035가 대체 |

## 배경 / 목적

ColorTrip은 사용자가 Kakao 계정으로 시작해 퀘스트 진행, 지도 색칠, 타임라인 기록을 누적하는 앱이다. 인증/회원 도메인은 사용자를 식별하고, 보호 API에서 현재 active user를 안정적으로 판별하며, 탈퇴 후 개인정보를 보존/익명화하는 기준을 제공한다.

origin/dev의 백엔드는 이미 `backend/app/` 도메인 패키지 구조, 공통 Envelope, 공통 예외, UUID v7, Soft Delete 기반을 갖고 있다. 이 기능은 과거 root `app/` 기반 구현을 그대로 옮기지 않고, 현재 백엔드 구조에 맞춰 `backend/app/auth/` 도메인으로 재구성한다.

## 목표 (Goals)

| ID | 목표 |
|----|------|
| AUTH-01 | Kakao access token 또는 authorization code 기반 로그인 |
| AUTH-02 | 최초 Kakao 로그인 시 자동 회원가입 |
| AUTH-03 | 저장형 refresh token 무효화 기반 로그아웃 |
| AUTH-04 | Access/Refresh token 발급 및 refresh token rotation |
| USER-01 | JWT 보호 API에서 내 정보 조회 |
| USER-03 | 회원 탈퇴, refresh token 전체 무효화, 탈퇴 유예/익명화 처리 |
| CMN-06 | 후속 API가 재사용할 `CurrentUser` 인증 dependency 제공 |

## 비목표 (Non-Goals)

- Google 로그인.
- access token blacklist. 탈퇴/익명화 사용자는 매 요청 active user DB 조회로 차단한다.
- 30일 보존 이후 hard delete batch.
- Flutter `flutter_secure_storage` 연동.
- GCP Secret Manager에 실제 운영 시크릿 등록.

## 요구사항

**기능**
- `POST /api/v1/auth/login/social`: Kakao access token 또는 authorization code 중 하나로 로그인한다.
- `POST /api/v1/auth/refresh`: refresh token을 rotation하고 새 access/refresh token을 반환한다.
- `POST /api/v1/auth/logout`: 현재 refresh token을 무효화한다.
- `GET /api/v1/users/me`: 현재 active user profile을 반환한다.
- `DELETE /api/v1/users/me`: 회원을 soft delete하고 활성 refresh token을 모두 무효화한다.

**비기능**
- 응답은 `code/status/message/data` Envelope를 따른다.
- DB는 PostgreSQL, SQLAlchemy async, UUID v7, `created_at/updated_at/deleted_at` 공통 컬럼을 따른다.
- access token TTL은 15분, refresh token TTL은 14일이다.
- refresh token 원문은 저장하지 않고 HMAC-SHA256 hash만 저장한다.
- Kakao API 키와 JWT secret은 환경변수 또는 GCP Secret Manager로 주입한다.

## 설계 개요 / 접근 방식

```text
Kakao Login
===========
Client
  |
  | POST /api/v1/auth/login/social
  v
auth.router
  |
  | validate one of access_token / authorization_code
  v
auth.service
  |---- authorization_code -> Kakao token API
  |---- Kakao access token -> Kakao user info API
  |---- find/create/restore/anonymize user
  |---- create access JWT + refresh token hash row
  v
Envelope(code/status/message/data)

Protected API
=============
Authorization: Bearer <access JWT>
  |
  v
CurrentUser dependency
  |---- decode JWT
  |---- load users where deleted_at IS NULL and anonymized_at IS NULL
  v
endpoint receives active User
```

## 의사결정 (함께 논의 · 근거 필수)

| 결정할 항목 | 선택지 | 결정 / 근거 | 상태 |
|------|--------|------------|------|
| 구현 위치 | root `app/` / `backend/app/auth/` | **`backend/app/auth/`** — origin/dev의 도메인 패키지 구조와 배포 Dockerfile 기준을 따른다. | 합의됨 |
| 응답 Envelope | `code/message/data` / `code/status/message/data` | **`code/status/message/data`** — `docs/conventions/api-design.md`의 단일 출처를 따른다. | 합의됨 |
| refresh token 저장 | stateless JWT / DB 저장 hash | **DB 저장 hash** — 로그아웃, rotation, 재사용 감지, 탈퇴 시 전체 revoke가 필요하다. | 합의됨 |
| 탈퇴 유예 | 7일 / 30일 / 분리 | **7일 복구 유예 + 30일 보존 정책** — 앱 복구 경험과 DB 보존 컨벤션을 분리한다. | 합의됨 |
| dev OAuth 페이지 | 운영 API / dev-only / 제거 | **제거** — 정식 앱 코드에는 개발용 HTML 라우트를 포함하지 않고, 수동 검증은 외부 클라이언트로 수행한다. | 합의됨 |
| 테스트 DB | SQLite / PostgreSQL | **PostgreSQL** — 모델이 PostgreSQL dialect와 asyncpg를 기준으로 하므로 SQLite 테스트는 제외한다. | 합의됨 |

## 영향 범위

- `backend/app/auth/`: auth/member 도메인 신규 추가.
- `backend/app/core/`: config, security primitive, error code 확장.
- `backend/alembic/`: users/refresh_tokens 마이그레이션 추가.
- `backend/tests/`: PostgreSQL 기반 auth 테스트 추가.
- `README.md`, `backend/README.md`, `docs/conventions/auth-security.md`, `docs/conventions/database.md`: 문서 동기화.

## 작업 단계

- [x] origin/dev 구조 분석 및 root auth 구현 재구성 방향 확정.
- [x] auth/member spec 문서 작성.
- [x] backend auth 도메인 모델/스키마/repository/service/router 구현.
- [x] JWT `CurrentUser` dependency 구현.
- [x] Kakao dev-only OAuth 검증 페이지 제거.
- [x] Alembic users/refresh_tokens 리비전 추가.
- [x] PostgreSQL 기반 테스트 추가.
- [x] root `app/`, root `tests/`, root backend용 `pyproject.toml`, root `uv.lock` 정리.

## 리스크 / 미해결 질문

- 테스트 DB가 로컬에 없으면 `docker compose -f docker-compose.test.yml up -d`가 선행되어야 한다.
- `local/test` 외 환경은 placeholder JWT secret 사용을 앱 시작 시 거부한다.
- 운영 Secret Manager 등록은 별도 인프라 작업이다. dev 배포는 `colortrip-dev-jwt-secret-key`를 필수 secret으로 사용한다.
- 30일 이후 hard delete batch는 별도 M3 작업으로 관리한다.
