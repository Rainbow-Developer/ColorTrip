# [구현 수준] Kakao 통합 인증

| 항목 | 내용 |
|------|------|
| 상태 | 구현 완료 / Android 실제 Kakao E2E 통과 |
| 최종 업데이트 | 2026-07-27 |

## 구현 단위

- [x] **백엔드** — Kakao `app_id` 검증, 프로필·versioned consent, `ActiveUser`·`ProfiledUser`·`CurrentUser`, 즉시 익명화 탈퇴와 Alembic migration.
- [x] **배포** — Kakao 설정 전달, 같은 이미지의 `alembic upgrade head` 성공 후 API 교체, 실패 시 교체 중단.
- [x] **Flutter** — Kakao SDK, secure storage, Dio JWT/단일 refresh, 서버 상태 기반 온보딩·프로필·로그아웃·탈퇴.
- [x] **실제 E2E** — Android 플랫폼 설정 보완 후 실제 Kakao 로그인·온보딩·세션 복구·refresh rotation·프로필·로그아웃·재로그인·unlink·즉시 익명화·재가입 신규 온보딩까지 통과했다.

## 구현된 항목

### 백엔드·DB

- [x] Flutter의 Kakao access token을 token-info에서 검증하고 정수 `app_id`가 `KAKAO_APP_ID`와 일치할 때만 user-info를 조회한다.
- [x] timeout, 잘못된 JSON·사용자 ID·token, 다른 앱 token을 `SOCIAL_AUTH_ERROR`로 정규화하며 authorization-code 경로를 유지한다.
- [x] 사용자 프로필과 현재 version의 terms/privacy/marketing consent를 한 트랜잭션으로 멱등 저장한다.
- [x] 프로필 완료 후 온보딩 endpoint를 다시 호출해 이메일을 변경하는 우회도 차단하되, 같은 이메일을 사용한 재동의는 허용한다.
- [x] 프로필·필수 동의·DNA로 `profile → trip_dna → complete`를 계산한다.
- [x] `ActiveUser`·`ProfiledUser`·`CurrentUser` dependency로 온보딩 단계 우회를 서버에서 차단한다.
- [x] DNA 제출은 유효한 질문–선택지 조합뿐 아니라 모든 활성 질문에 정확히 한 번씩 답했을 때만 완료한다.
- [x] refresh token HMAC hash, rotation, row lock, 이전 token 재사용 거부, logout/withdraw revoke를 유지한다.
- [x] 탈퇴 즉시 PII·DNA를 제거하고 social ID를 익명화하며 consent·refresh token을 삭제한다. 도메인 기록은 보존한다.
- [x] `user_consents`와 기존 soft-deleted user 익명화 migration을 단일 Alembic head에 추가했다.
- [x] 구버전 API와 신버전 migration이 겹치는 배포 구간에도 PII가 남지 않도록 DB trigger를 적용했다.

### Flutter

- [x] KakaoTalk 설치 여부에 따른 Talk 로그인과 Kakao Account fallback, 취소·오류 분류, logout·unlink adapter를 구현했다.
- [x] Native App Key와 API base URL을 빌드 설정으로 주입하고 누락 시 로그인 전에 설정 오류를 표시한다.
- [x] ColorTrip access/refresh token과 탈퇴 재시도 단계를 `flutter_secure_storage`에 직렬화해 저장한다.
- [x] Dio bearer 주입, 동시 401 single-flight refresh, token rotation compare-and-swap, 원 요청 1회 재시도를 구현했다.
- [x] 재전송할 수 없는 multipart 요청은 자동 replay하지 않고 명시적 오류로 종료한다.
- [x] 서버 `onboarding_step`을 단일 출처로 bootstrap·회원가입·DNA·홈·탈퇴 재시도 라우팅을 구현했다.
- [x] 프로필/동의 validation·date picker·중복 제출 방지·응답 유실 복구, 프로필 조회·수정, 홈·공유 사용자 동기화를 구현했다.
- [x] logout은 서버 revoke 실패에도 로컬 세션을 종료하고, withdrawal은 unlink 뒤 백엔드 실패 시 JWT와 재시도 상태를 보존한다.
- [x] Android cleartext는 debug에만 허용하고 backup을 끄며, iOS Keychain Sharing entitlement를 구성했다.
- [x] 시스템 뒤로가기를 포함해 프로필 온보딩과 첫 DNA 단계 이탈 시 확인 후 로그아웃한다.
- [x] Kakao SDK 오류를 민감정보 없이 플랫폼·키·동의·네트워크 범주로 진단한다.

## 검증 결과

- [x] backend PostgreSQL pytest: 133 passed.
- [x] backend Ruff check/format, Pyright: 통과.
- [x] onboarding 원자성·멱등성·동시성, 접근 단계, refresh rotation, 탈퇴/익명화 회귀 테스트.
- [x] migration 빈 DB·기존 head·legacy PII backfill·overlap trigger·단일 head·배포 실패 중단 테스트.
- [x] Flutter unit/widget test: 72 passed.
- [x] Flutter analyze·Dart format: 통과.
- [x] Android fake-repository integration test: 로그인 → 프로필/동의 → DNA → 홈 → 프로필/로그아웃과 세션 복구 2개 시나리오 통과.
- [x] Android release APK build: 통과.
- [ ] iOS `--no-codesign` build: 이 PC의 Xcode 설치가 불완전하고 CocoaPods가 없어 Flutter가 컴파일 전에 차단했다. iOS 실제 로그인과 함께 범위 밖 환경 제약으로 기록한다.
- [x] 실제 Android emulator에서 Kakao Account fallback, OAuth callback, app ID 검증, ColorTrip 사용자·세션 생성을 확인했다.
- [x] 실제 신규 온보딩 저장, DNA 완료, 홈 진입, 앱 강제 종료 후 세션 복구를 확인했다.
- [x] 실제 access token 만료 뒤 앱 재시작 시 refresh token 전체 행은 1개 증가하고 활성 행은 1개로 유지되어 rotation을 확인했다.
- [x] 실제 프로필 닉네임 수정·서버 저장·앱 재시작 후 재조회와 원래 값 복원을 확인했다.
- [x] 실제 로그아웃 뒤 활성 refresh token 폐기, 재로그인 뒤 기존 사용자의 온보딩 생략을 확인했다.
- [x] 실제 Kakao unlink → 백엔드 즉시 익명화, 동의 삭제, 모든 refresh token 폐기, 기존 access token `401`, 설문 기록 보존을 확인했다.
- [x] 탈퇴 뒤 Kakao 필수 동의만으로 재로그인해 새 사용자와 `profile` 판정을 확인하고, 합성 프로필·필수 ColorTrip 동의·마케팅 미동의·DNA 4문항을 완료했다.
- [x] 재가입 완료 뒤 앱을 강제 종료·재시작해 새 세션이 홈으로 복구되는 것을 확인했다.

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
| 2026-07-27 | backend·Flutter·배포 구현과 자동 검증 결과, 실제 Kakao E2E 외부 설정 blocker 기록 |
| 2026-07-27 | Android 플랫폼 설정 보완 뒤 실제 로그인·온보딩·세션 복구·refresh·로그아웃·재로그인 검증, 탈퇴 실행 승인만 대기로 갱신 |
| 2026-07-27 | 사용자 승인 뒤 실제 Kakao unlink·즉시 익명화·토큰 차단·도메인 보존 검증, 재가입 Kakao 동의 화면 대기로 갱신 |
| 2026-07-27 | 탈퇴 후 필수 Kakao 동의만으로 새 사용자·프로필·동의·DNA·홈·세션 복구까지 실제 Android E2E 완료 |
