# [설명] Kakao 통합 인증

## 개요

Kakao 통합 인증은 Flutter 앱의 Kakao SDK 로그인부터 ColorTrip 백엔드의 JWT 세션, 프로필·동의 온보딩, 단계별 보호 API, 프로필 관리와 탈퇴까지 연결하는 기능이다. 이 문서의 백엔드·배포 범위는 KAN-53에서 제공하며, Flutter SDK와 앱 화면 연동은 KAN-54에서 이어서 제공한다.

백엔드는 Kakao access token이 유효한지만 확인하지 않고 발급 Kakao 앱의 `app_id`도 검증한다. 로그인한 사용자는 프로필·현재 필수 동의·여행 DNA를 모두 완료해야 일반 도메인 API를 사용할 수 있다. ColorTrip JWT는 secure storage에 보관하고 access token 만료 시 refresh rotation으로 갱신한다.

## 동작 방식

### 로그인과 온보딩

```text
Kakao Flutter SDK 로그인
  → Kakao access token
  → POST /api/v1/auth/login/social
     {"provider":"kakao","access_token":"..."}
  → Kakao token info의 app_id 검증
  → Kakao user info 조회
  → ColorTrip access/refresh token 발급
  → secure storage 저장
  → ActiveUser
      └─ 프로필 + 현재 필수 동의 제출 → ProfiledUser
          └─ 여행 DNA 답변 제출 → CurrentUser
  → 일반 보호 API
```

접근 단계는 서버가 판정한다.

| 단계 | 조건 | 허용 범위 |
|------|------|------|
| `ActiveUser` | 유효한 JWT, 탈퇴·익명화되지 않은 user | 내 프로필 조회, 프로필·동의 입력, 로그아웃, 탈퇴 |
| `ProfiledUser` | `ActiveUser` + 프로필 + 현재 `terms-v1`, `privacy-v1` 동의 | 여행 DNA 질문 조회·답변 제출 |
| `CurrentUser` | `ProfiledUser` + DNA 완료 | 여행·퀘스트·지도·타임라인·공유·업로드 등 일반 보호 API |

마케팅 동의(`marketing-v1`)는 선택이며 단계 판정에 사용하지 않는다. 세 consent 버전은 클라이언트가 보내지 않고 서버 상수로 기록한다. 단계가 부족한 보호 API는 HTTP 403 `ONBOARDING_REQUIRED`를 반환하며 앱은 `/users/me`의 `onboarding_step`을 다시 확인한다.

`onboarding_step`은 별도 상태 컬럼 없이 현재 데이터로 계산한다.

- `profile`: 닉네임·이메일·생년월일 중 누락이 있거나 현재 필수 consent가 없음
- `trip_dna`: 프로필·필수 consent 완료, DNA 미완료
- `complete`: 프로필·필수 consent·DNA 완료

`PUT /api/v1/users/me/onboarding-profile`은 프로필과 consent를 한 트랜잭션으로 저장한다. 같은 요청은 멱등하며 필수 동의가 `false`이면 저장하지 않는다. `PATCH /api/v1/users/me`는 닉네임·생년월일만 수정하고 이메일은 읽기 전용이다.

```json
{
  "nickname": "컬러트립",
  "email": "user@example.com",
  "birth_date": "2000-01-01",
  "terms_agreed": true,
  "privacy_agreed": true,
  "marketing_agreed": false
}
```

`user_consents`는 `consent_type`, 서버 version, `agreed`, `decided_at`과 공통 시각을 기록한다. `(user_id, consent_type, version)`은 유일하며 동일 요청은 upsert로 수렴한다. 마케팅 미동의도 `false` 행으로 남고, 새 version은 과거 이력을 덮지 않는다. 성공 응답은 공통 Envelope의 `data`에 최신 `UserProfile`을 담는다.

탈퇴 시 consent는 일반 soft-delete 규칙의 개인정보 삭제 예외로 물리 삭제한다.

### JWT 갱신

Flutter의 Dio 계층은 secure storage의 access token을 Bearer header에 넣는다. access token 만료 응답을 받으면 한 번의 refresh 요청으로 access/refresh token을 rotation하고 원 요청을 한 번 재시도한다. 동시에 여러 요청이 만료되어도 하나의 refresh만 실행한다. refresh가 만료되거나 거부되면 저장 토큰과 사용자 상태를 지우고 로그인 화면으로 이동한다.

refresh API는 만료된 access token을 요구하지 않는다. refresh token의 hash·만료·rotation 상태를 검증하고 연결된 사용자가 active인지 DB에서 독립적으로 확인한다.

### 프로필과 로그아웃

프로필 SOT는 백엔드이며 수집 필드는 닉네임, 이메일, 생년월일이다. Kakao 닉네임·이메일·이미지는 신규 사용자 초기값으로만 사용하며 재로그인으로 기존 프로필을 덮어쓰지 않는다. `UserProfile`은 프로필과 DNA, `social_provider`, 계산된 `onboarding_step`, 항상 `false`인 호환 필드 `is_restored`를 반환한다.

로그아웃은 백엔드 refresh token 폐기를 제한 횟수 재시도하고 Kakao logout을 best-effort로 호출한 뒤 Flutter secure storage와 메모리 상태를 삭제한다. 백엔드 또는 Kakao logout이 실패해도 사용자가 해당 기기에서 로그아웃할 수 있도록 로컬 세션은 삭제한다.

### 탈퇴

```text
1. Flutter Kakao SDK unlink
2. DELETE /api/v1/users/me
3. 백엔드 성공
4. Flutter secure storage·로컬 사용자 상태 삭제
```

Kakao unlink 뒤 백엔드 요청이 실패하면 Flutter는 ColorTrip JWT를 보존해 탈퇴를 재시도한다. Kakao가 이미 unlink된 상태도 오류로 끝내지 않고 백엔드 탈퇴 재시도로 이어간다.

백엔드는 탈퇴 성공 트랜잭션 하나에서 다음을 수행한다.

- 활성 refresh token 전체 폐기
- consent 삭제
- 닉네임·이메일·생년월일·프로필 이미지·DNA 제거
- `social_id`를 `deleted:{user_id}`로 치환
- `deleted_at`과 `anonymized_at` 기록

인증 PII는 즉시 익명화되고 계정 복구는 제공하지 않는다. 도메인 기록은 삭제하지 않고 익명화된 user와의 참조를 보존한다. 이후 같은 Kakao 계정으로 로그인하면 새 user가 생성된다.

## 주요 구성 요소 / 위치

아래 위치는 구현 계획 기준이며, 현재 구현 여부는 [implementation.md](./implementation.md)를 따른다.

| 구성 요소 | 역할 | 위치 |
|-----------|------|------|
| 인증 API·서비스 | Kakao 검증, JWT, 프로필·consent, 탈퇴 | `backend/app/auth/` |
| 인증 dependency | `ActiveUser`·`ProfiledUser`·`CurrentUser` 접근 제어 | `backend/app/auth/dependencies.py` |
| 인증 설정·보안 | Kakao app ID, consent version, JWT 생성·검증 | `backend/app/core/` |
| DB migration | user·consent schema 변경 | `backend/alembic/versions/` |
| Flutter 인증 adapter | Kakao Flutter SDK 로그인·unlink | `frontend/lib/`의 인증 data 계층 |
| Flutter 세션 | secure storage와 Dio refresh 직렬화 | `frontend/lib/core/`, `frontend/lib/data/` |
| 온보딩·프로필 UI | 프로필·consent·프로필 수정·탈퇴 | `frontend/lib/features/onboarding/`, `frontend/lib/features/profile/` |
| 라우팅·상태 | 서버 접근 단계에 따른 화면 전환 | `frontend/lib/app/`, `frontend/lib/state/` |
| dev 배포 | Alembic 자동 적용 후 API 교체 | `deploy/`, `.github/workflows/deploy-dev.yml` |
| 통합 검증 | backend·Flutter 자동 테스트와 emulator E2E | `backend/tests/`, `frontend/test/`, `frontend/integration_test/` |

## 설정 / 사용법

실제 값은 저장소에 기록하지 않고 로컬 `.env` 또는 GCP Secret Manager로 주입한다.

| 설정 | 용도 |
|------|------|
| `KAKAO_APP_ID` | Kakao token info의 발급 앱 검증 |
| `KAKAO_TOKEN_INFO_URL` | Kakao access token 검증 endpoint |
| `KAKAO_CLIENT_SECRET` | 활성화된 경우 기존 authorization code 교환 시 client secret |
| `KAKAO_REST_API_KEY` | 기존 authorization code 교환 |
| `KAKAO_REDIRECT_URI` | 기존 authorization code redirect |
| `JWT_SECRET_KEY` | ColorTrip JWT 서명 |

Flutter 빌드에는 Kakao Native App Key와 Android package/key hash 설정이 별도로 필요하다. 이 값도 source에 직접 작성하지 않고 빌드 설정으로 주입한다.

## 예시

1. 신규 사용자가 Android emulator에서 Kakao 로그인을 완료한다.
2. 백엔드가 Kakao token info의 `app_id`가 설정값과 일치하는지 검증한다.
3. 앱은 받은 ColorTrip JWT를 secure storage에 저장한다.
4. 사용자는 닉네임·이메일·생년월일과 이용약관·개인정보 필수 동의를 한 번에 제출하고 선택적으로 마케팅에 동의한다.
5. 서버가 사용자를 `ProfiledUser`로 판정하고 여행 DNA 질문·답변만 허용한다.
6. DNA 완료 후 `CurrentUser`로 판정해 홈과 도메인 API 접근을 허용한다.
7. 사용자가 탈퇴하면 Kakao unlink, 백엔드 즉시 익명화, 로컬 데이터 삭제 순서로 완료한다.

## 관련 문서

- [035 구현 수준](./implementation.md)
- [인증 & 보안 · 개인정보 컨벤션](../../conventions/auth-security.md)
- [기존 백엔드 인증/회원 기반](../005-auth-member/)
- [프론트엔드 앱](../000-frontend-app/)
- [DB 마이그레이션](../015-database-migration/)
- [README 환경 변수와 현재/계획 구분](../../../README.md)
