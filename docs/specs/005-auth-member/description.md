# [설명] 인증/회원 (Auth/Member)

| 항목 | 내용 |
|------|------|
| 기능명 | 인증/회원 (Auth/Member) |
| Spec 폴더 | `docs/specs/005-auth-member/` |
| 영역 | backend |
| 상태 | 진행 중 |

## 기능 설명

인증/회원 도메인은 Kakao 계정을 ColorTrip user로 연결하고, JWT 기반 보호 API에서 현재 active user를 주입한다. 사용자가 탈퇴하면 refresh token을 모두 무효화하고, 7일 동안 같은 Kakao 계정 재로그인으로 복구할 수 있게 한다. 7일이 지나면 기존 계정은 익명화하고 같은 Kakao 계정으로 새 user를 만들 수 있다.

## 주요 구성 요소

| 구성 요소 | 위치 | 역할 |
|------|------|------|
| auth 도메인 | `backend/app/auth/` | 모델, 스키마, repository, service, router, dependency |
| 공통 보안 primitive | `backend/app/core/security.py` | access JWT 생성/검증, refresh token 생성/hash |
| 공통 설정 | `backend/app/core/config.py` | JWT/Kakao/dev route 설정 |
| 공통 응답/예외 | `backend/app/core/response.py`, `backend/app/core/exceptions.py` | Envelope와 error code 변환 |
| 마이그레이션 | `backend/alembic/versions/` | users, refresh_tokens 테이블 |

## API

| Method | URI | 설명 | 인증 |
|------|------|------|------|
| POST | `/api/v1/auth-tokens` | Kakao 로그인, 자동 가입, token 발급 | 없음 |
| POST | `/api/v1/auth-token-renewals` | refresh token rotation | 없음 |
| DELETE | `/api/v1/auth-tokens/current` | 로그아웃, refresh token 무효화 | Bearer access token |
| GET | `/api/v1/users/me` | 내 정보 조회 | Bearer access token |
| DELETE | `/api/v1/users/me` | 회원 탈퇴 | Bearer access token |

응답은 모두 공통 Envelope를 사용한다.

```json
{
  "code": "SUCCESS",
  "status": 200,
  "message": "요청이 성공했습니다.",
  "data": {}
}
```

## 탈퇴 상태

```text
ACTIVE
  |
  | DELETE /api/v1/users/me
  v
WITHDRAWN_GRACE
  deleted_at != null
  withdrawal_grace_until = deleted_at + 7 days
  refresh_tokens all revoked
  |
  | same Kakao login within 7 days
  v
ACTIVE (restored)

WITHDRAWN_GRACE
  |
  | same Kakao login after 7 days
  v
ANONYMIZED_OLD_USER + NEW_ACTIVE_USER
```

## 보호 API 작성 규칙

- 새 보호 API는 `CurrentUser` dependency를 사용한다.
- endpoint와 service에는 raw JWT를 전달하지 않는다.
- access token 검증과 active user 조회는 dependency 계층에서 끝낸다.
- service는 이미 식별된 user 또는 user id를 입력으로 받는다.

## Dev-only OAuth 검증

로컬 실제 Kakao OAuth 테스트를 위해 dev-only 라우터를 제공한다.

- `/dev/kakao-login-test`: Kakao authorize URL로 이동하는 HTML 페이지.
- `/dev/kakao/callback`: authorization code를 backend login API로 교환하는 callback.

이 라우터는 설정값이 켜진 경우에만 mount한다. 운영/배포 환경의 기본값은 off다.
