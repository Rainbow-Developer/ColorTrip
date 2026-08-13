# [구현 수준] Kakao 통합 인증

| 항목 | 내용 |
|------|------|
| 상태 | 백엔드·배포 구현 완료 / Flutter는 KAN-54 후속 PR 예정 |
| 최종 업데이트 | 2026-07-28 |

## 구현 단위

- [x] **백엔드** — Kakao `app_id` 검증, 프로필·versioned consent, `ActiveUser`·`ProfiledUser`·`CurrentUser`, 즉시 익명화 탈퇴와 Alembic migration.
- [x] **배포** — Kakao 설정 전달, 같은 이미지의 `alembic upgrade head` 성공 후 API 교체, 실패 시 교체 중단.
- [ ] **Flutter (KAN-54)** — Kakao SDK, secure storage, Dio JWT/단일 refresh, 서버 상태 기반 온보딩·프로필·로그아웃·탈퇴.
- [ ] **Android 실제 E2E (KAN-54)** — Flutter PR 병합 전 실제 Kakao 로그인부터 탈퇴까지의 흐름을 다시 검증한다.

## 구현된 항목

### 백엔드·DB

- [x] Flutter의 Kakao access token을 token-info에서 검증하고 정수 `app_id`가 `KAKAO_APP_ID`와 일치할 때만 user-info를 조회한다.
- [x] timeout, 잘못된 JSON·사용자 ID·token, 다른 앱 token을 `SOCIAL_AUTH_ERROR`로 정규화하며 authorization-code 경로를 유지한다.
- [x] 사용자 프로필과 현재 version의 terms/privacy/marketing consent를 한 트랜잭션으로 멱등 저장한다.
- [x] 프로필 완료 후 온보딩 endpoint를 다시 호출해 이메일을 변경하는 우회도 차단하되, 같은 이메일을 사용한 재동의는 허용한다.
- [x] 프로필·필수 동의·DNA로 `profile → trip_dna → complete`를 계산한다.
- [x] `ActiveUser`·`ProfiledUser`·`CurrentUser` dependency와 일반 보호 API의 온보딩 단계 차단을 제공한다.
- [ ] Trip DNA 질문·답변 API의 `ProfiledUser` 적용은 기존 Flutter 설문 흐름과 함께 KAN-54에서 전환한다.
- [x] DNA 제출은 유효한 질문–선택지 조합뿐 아니라 모든 활성 질문에 정확히 한 번씩 답했을 때만 완료한다.
- [x] refresh token HMAC hash, rotation, row lock, 이전 token 재사용 거부, logout/withdraw revoke를 유지한다.
- [x] 탈퇴 즉시 PII·DNA를 제거하고 social ID를 익명화하며 consent·refresh token을 삭제한다. 도메인 기록은 보존한다.
- [x] `user_consents`와 기존 soft-deleted user 익명화 migration을 단일 Alembic head에 추가했다.
- [x] 구버전 API와 신버전 migration이 겹치는 배포 구간에도 PII가 남지 않도록 DB trigger를 적용했다.

### Flutter 후속 범위 (KAN-54)

- [ ] KakaoTalk/Kakao Account 로그인·logout·unlink adapter와 플랫폼 callback 설정.
- [ ] secure storage, Dio bearer·single-flight refresh, 서버 `onboarding_step` 기반 라우팅.
- [ ] 프로필·동의·DNA·프로필 수정·로그아웃·탈퇴 재시도 화면과 사용자 상태 동기화.

## 검증 결과

- [x] backend PostgreSQL pytest: 133 passed.
- [x] backend Ruff check/format, Pyright: 통과.
- [x] onboarding 원자성·멱등성·동시성, 접근 단계, refresh rotation, 탈퇴/익명화 회귀 테스트.
- [x] migration 빈 DB·기존 head·legacy PII backfill·overlap trigger·단일 head·배포 실패 중단 테스트.
- [ ] Flutter unit/widget 및 Android E2E 검증은 KAN-54에서 수행한다.

## 알려진 한계 / TODO

- Kakao Developers의 Android package·key hash·동의항목은 저장소 밖 외부 설정이다. 실제 키와 token을 문서·Git에 저장하지 않는다.
- 백엔드 탈퇴 commit 뒤 성공 응답만 유실되면 클라이언트가 성공 여부를 완전히 판별할 operation ID/조회 API가 없다. 현재는 unlink 단계와 JWT를 보존해 재시도한다.
- 기존 authorization-code 로그인 경로는 호환을 위해 유지한다.
- Android 실기기 KakaoTalk 전환, iOS 실제 로그인, HTTPS, 외부 unlink webhook, 법률 문서 본문/URL, 도메인 기록 삭제는 범위 밖이다.
- 여행 DNA seed는 멱등 명령으로 제공하며, 운영 질문을 배포마다 덮어쓰지 않도록 migration과 분리한다.

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-07-25 | 승인된 Kakao 통합 인증 범위의 계획 문서 최초 작성 |
| 2026-07-28 | CodeRabbit 검토 범위 분리를 위해 백엔드·배포를 KAN-53, Flutter와 실제 Android E2E를 KAN-54로 분리 |
| 2026-08-13 | **생년월일을 선택 필드로 전환(KAN-75)** — `OnboardingProfileRequest.birth_date`를 `date \| None`으로 내리고, `_profile_is_complete`(=`onboarding_step` 판정)에서 제외했다. 포함해 두면 생년월일을 건너뛴 사용자가 `profile` 단계에 영구히 묶인다. 함께 드러난 결함: 이메일 잠금 조건이 `_profile_is_complete`를 재사용하고 있어, 생년월일이 필수일 때만 우연히 동작했다(Kakao가 닉네임·이메일을 프리필하므로 선택 전환 즉시 신규 가입자가 첫 제출부터 422). 잠금 기준을 `is_profiled_user`(consent 포함)로 바꿨다. 재제출 시 기존 생년월일을 지우지 않는다. 테스트 3건 추가 |
