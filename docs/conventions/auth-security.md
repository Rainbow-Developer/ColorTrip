# [컨벤션] 인증 & 보안 · 개인정보

> **범위**: 소셜 로그인·토큰·토큰 저장·개인정보·시크릿·CORS
> **변경 시**: 이 문서를 단일 출처로 갱신합니다 ([AGENT_GUIDE 문서 동기화](../AGENT_GUIDE.md#문서-동기화-필수) 참고).

## 결정 사항

| 항목 | 결정 | 비고 |
|------|------|------|
| 소셜 로그인 방식 | Kakao 직접 구현 (옵션 A) | |
| 소셜 제공자 범위 | Kakao | |
| Kakao 앱 검증 | token info의 `app_id`를 `KAKAO_APP_ID`와 비교 | 다른 Kakao 앱 token 거부 |
| 토큰 전략 | Access + Refresh (JWT) | |
| Access token TTL | 15분 | 짧은 TTL, blacklist 미사용 |
| Refresh token TTL | 14일 | DB 저장 hash + rotation |
| Refresh token 저장 | 서버 DB에 hash 저장 | 원문 저장 금지, 로그아웃/탈퇴 시 무효화 |
| 토큰 저장(클라이언트) | flutter_secure_storage | |
| 수집 개인정보 범위 | 닉네임, 생년월일, 프로필 이미지(선택) | 인증/프로필 PII 최소 범위. 프로필 이미지는 미등록 허용. 이메일은 쓰임이 없어 수집하지 않는다 |
| 동의 버전 | 서버 상수 `terms-v1`, `privacy-v1`, `marketing-v1` | 클라이언트가 version을 지정하지 않음. 출시 후 수집 항목이 바뀌면 해당 버전을 상향해 재동의를 받는다 |
| 보호 API 접근 단계 | `ActiveUser` → `ProfiledUser` → `CurrentUser` | 프로필·필수 동의·DNA 완료 여부를 서버에서 강제 |
| 탈퇴 정책 | 즉시 익명화, 복구 없음 | 035에서 005의 7일 복구 정책 대체 |
| 탈퇴 후 도메인 기록 | 익명화된 user에 연결해 보존 | 여행·퀘스트·지도·타임라인·공유 기록 삭제 제외 |
| Kakao unlink 순서 | 클라이언트 unlink → 백엔드 탈퇴 → 로컬 삭제 | 백엔드 실패 시 JWT를 보존해 재시도 |
| 비밀 / 키 관리 | GCP Secret Manager | |
| CORS 정책 | 허용 도메인 화이트리스트 | |
| 로컬 Kakao 검증 | Flutter Kakao SDK + 정식 API | authorization-code 경로는 호환용 외부 클라이언트에서만 검증 |

Flutter/Android Kakao SDK 초기화에는 **네이티브 앱 키**를 사용한다. REST API 키와 Admin 키는
각각 REST API 호출과 Admin API 호출에만 사용하며, `KAKAO_NATIVE_APP_KEY`에 전달하지 않는다.
Android 플랫폼에는 앱 패키지명 `io.vmonster.colortrip`과 현재 APK 서명 키의 해시를 등록한다.
키 종류를 잘못 사용하면 `KOE101`이 발생하고, 등록하지 않은 서명 키로 실행하면
`KOE009 (invalid android_key_hash)`가 발생한다. 실행 절차와 해시 확인 명령은
[앱 실행 가이드](../app-run-guide.md#kakao-앱-키와-android-플랫폼-설정)를 따른다.

## 적용 상태

- KAN-53은 Kakao 앱 검증, versioned consent, `ActiveUser` 기반 온보딩 경계, 즉시 익명화 탈퇴를 구현한다. Flutter secure storage와 Trip DNA의 `ProfiledUser` 경계는 KAN-54에서 함께 적용한다.
- [005-auth-member](../specs/005-auth-member/)는 이전 백엔드 기반의 구현 기록으로 유지한다. 035가 이를 통합 확장하고 7일 복구 정책을 대체했으며, 기존 authorization code 경로는 제거하지 않았다.
- 구현 여부는 각 spec의 `implementation.md`를 따른다. 정책의 목표값은 이 문서의 결정 사항 표를 따른다.

## 규칙 / 적용

- 인증은 Kakao 직접 구현 + JWT(Access/Refresh)로 처리한다.
- Flutter는 Kakao Flutter SDK로 access token을 얻고 백엔드 정식 로그인 API에 전달한다.
- 백엔드는 Kakao token info API의 `app_id`가 `KAKAO_APP_ID`와 일치하는지 확인한 뒤 user info를 조회한다. 클라이언트가 보낸 Kakao 사용자 ID나 프로필을 신뢰하지 않는다.
- Access token은 15분 TTL로 짧게 유지하고, access token blacklist는 사용하지 않는다.
- Refresh token은 서버 DB에 hash만 저장하고, 재발급 시 rotation한다.
- 로그아웃과 탈퇴는 저장된 refresh token을 `deleted_at`으로 무효화한다.
- 클라이언트 토큰은 flutter_secure_storage에만 저장한다.
- 시크릿은 코드/깃에 두지 않고 GCP Secret Manager를 사용한다(외부 API 키 관리도 동일).
- `local/test` 외 환경은 `JWT_SECRET_KEY`, `KAKAO_APP_ID`, `KAKAO_REST_API_KEY`, `KAKAO_REDIRECT_URI`를 배포 설정으로 주입하고, Kakao 개발자 설정에서 client secret을 활성화한 환경만 `KAKAO_CLIENT_SECRET`도 주입한다. 기본 placeholder secret이나 해당 환경의 필수 Kakao 설정 누락으로 앱이 시작되지 않아야 한다.
- CORS는 허용 도메인 화이트리스트로 제한한다.
- 정식 Flutter 경로는 Kakao SDK access token을 `POST /api/v1/auth/login/social`에 전달해 검증한다. 호환용 authorization-code 경로를 수동 검증할 때만 앱에 개발용 라우트를 추가하지 않고 별도 로컬 클라이언트를 사용한다.

## 프로필·동의와 보호 API 사용자 조회

- 인증/프로필 개인정보 수집은 닉네임, 생년월일, 프로필 이미지로 제한한다. 프로필 이미지는 선택이며 등록하지 않아도 서비스 이용에 제약이 없다. 이메일은 서비스 어디에서도 쓰이지 않아 수집하지 않으며, Kakao 동의항목에서도 요청하지 않는다.
- 동의 version은 클라이언트 입력이 아니라 서버 상수 `terms-v1`, `privacy-v1`, `marketing-v1`를 사용한다.
- 이용약관과 개인정보 동의는 필수이고 마케팅 동의는 선택이다. 현재 필수 version 동의가 없으면 일반 도메인 API 접근을 허용하지 않는다.
- `ActiveUser`는 access JWT 검증 후 active user(`deleted_at IS NULL`, `anonymized_at IS NULL`)를 DB에서 조회한다. 프로필·동의 온보딩, 로그아웃, 탈퇴처럼 유효한 access JWT가 필요한 API에 사용한다.
- `ProfiledUser`는 `ActiveUser`에 닉네임·생년월일과 현재 이용약관·개인정보 필수 동의 완료 조건을 더한다. 여행 DNA 질문·답변 API 적용은 Flutter 세션 연동을 포함한 KAN-54에서 수행한다.
- `CurrentUser`는 `ProfiledUser`에 DNA 완료 조건을 더한다. 여행·퀘스트·지도·타임라인·공유·퀘스트 사진 업로드 등 일반 보호 API에 사용한다.
- 프로필 이미지 업로드·삭제는 예외로 `ActiveUser`를 사용한다. 온보딩 중에 등록할 수 있어야 하므로 상위 단계를 요구할 수 없다([080 프로필 이미지](../specs/080-profile-image/)).
- 단계가 부족하면 HTTP 403 `ONBOARDING_REQUIRED`를 반환하고, 클라이언트는 `/users/me`의 계산된 `onboarding_step`을 다시 조회한다.
- endpoint는 필요한 최소 단계의 dependency를 받고, service에는 식별된 user 또는 user id만 전달한다.
- endpoint나 service에서 JWT를 직접 decode하지 않는다.
- service에는 raw JWT, Authorization header, refresh token을 사용자 식별용으로 넘기지 않는다.
- 보호 API 인증에는 access token만 사용한다. refresh token은 재발급과 로그아웃 요청에만 사용한다.
- refresh는 access-JWT dependency 밖에서 refresh token 자체를 인증하고, 연결된 user가 탈퇴·익명화되지 않았는지 DB에서 확인한다.
- 탈퇴 또는 익명화된 사용자는 남은 access token이 있어도 보호 API에 접근할 수 없다.

## 탈퇴와 익명화

- Flutter의 탈퇴 순서는 **Kakao SDK unlink → `DELETE /api/v1/users/me` → 백엔드 성공 후 secure storage·로컬 사용자 상태 삭제**로 고정한다.
- unlink 성공 후 백엔드 탈퇴가 실패하면 ColorTrip JWT를 삭제하지 않고 백엔드 탈퇴를 재시도한다. Kakao가 이미 unlink된 상태도 정상 재시도 경로로 처리한다.
- 백엔드는 탈퇴 성공 트랜잭션에서 refresh token 전체 폐기, consent 삭제, 닉네임·생년월일·프로필 이미지·DNA 제거, `social_id = deleted:{user_id}` 치환, `deleted_at`·`anonymized_at` 기록을 함께 수행한다.
- 익명화는 즉시 적용하며 계정 복구를 제공하지 않는다. 같은 Kakao 사용자의 이후 로그인은 새 user를 생성한다.
- 여행·퀘스트·지도·타임라인·공유 등 도메인 기록은 삭제하지 않고 익명화된 user에 연결해 보존한다.
- 외부 unlink webhook과 도메인 기록 삭제는 035 범위가 아니다.

## 관련 문서

- [외부 API & 데이터 연동](./external-apis.md)
- [035 Kakao 통합 인증](../specs/035-kakao-auth-integration/)
- [080 프로필 이미지](../specs/080-profile-image/)
- [005 이전 백엔드 인증/회원 기반](../specs/005-auth-member/)
