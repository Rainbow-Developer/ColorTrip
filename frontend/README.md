# ColorTrip Flutter

Kakao 로그인, ColorTrip JWT 세션, 프로필·동의·여행 DNA 온보딩과 여행 화면을 제공하는
Flutter 앱이다. 인증 계약의 단일 출처는
[035 Kakao 통합 인증](../docs/specs/035-kakao-auth-integration/)이다.

## 요구사항

- Flutter 3.44+ / Dart 3.12+
- Android 10(API 29)+ 또는 iOS 16+
- 실제 Kakao 로그인 시 Kakao Developers에 등록된 Native App Key
- 실행 중인 ColorTrip 백엔드 API

## 설치

```bash
cd frontend
flutter pub get
```

## 실행 설정

Native App Key와 API 주소는 source가 아니라 빌드 정의로 주입한다.

```bash
flutter run \
  --dart-define=KAKAO_NATIVE_APP_KEY=<native-app-key> \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

- Android emulator에서 호스트의 로컬 백엔드는 `10.0.2.2`로 접근한다.
- Android package와 iOS bundle ID는 `io.vmonster.colortrip`이다.
- Kakao Developers Android 플랫폼에 이 package와 현재 debug signing key hash를 등록해야 한다.
- `KAKAO_NATIVE_APP_KEY` 또는 `API_BASE_URL`이 없으면 앱이 설정 오류 화면을 표시한다.
- REST API key, Kakao client secret, ColorTrip JWT secret은 Flutter에 포함하지 않는다.
- Android cleartext HTTP는 debug manifest에서만 허용한다.

## 인증 구조

- `KakaoAuthGateway`: KakaoTalk 로그인, Kakao Account fallback, logout, unlink
- `AuthRepository`: ColorTrip 로그인·프로필·refresh·로그아웃·탈퇴 API
- `SecureTokenStorage`: access/refresh token과 탈퇴 재시도 상태 저장
- `AuthSessionInterceptor`: Bearer 주입, 동시 401 single-flight refresh, 원 요청 1회 재시도
- `AuthController`: bootstrap과 `profileRequired`·`tripDnaRequired`·`authenticated` 상태 관리
- GoRouter: 서버 `onboarding_step`을 기준으로 로그인·프로필·DNA·홈 접근 제어

토큰은 `flutter_secure_storage`에 저장한다. Kakao access token은 백엔드 로그인 교환에만
사용하고 ColorTrip 세션 토큰으로 보관하지 않는다.

## 플랫폼 설정

Android callback scheme과 debug 네트워크 설정은 `android/app/src/`에 구성돼 있다.
iOS URL scheme은 `ios/Runner/Info.plist`와
`ios/Flutter/configure_kakao_scheme.sh`가 빌드 시 Native App Key로 생성한다.

실제 키, key hash, token은 문서나 Git에 기록하지 않는다. 자세한 정책은
[인증·보안 컨벤션](../docs/conventions/auth-security.md)을 따른다.

## 검사

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --release \
  --dart-define=KAKAO_NATIVE_APP_KEY=<native-app-key> \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Android fake repository 통합 시나리오는 다음처럼 실행한다.

```bash
flutter test integration_test/kakao_auth_flow_test.dart -d <emulator-id> \
  --dart-define=KAKAO_NATIVE_APP_KEY=<native-app-key> \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

현재 Android emulator 실제 Kakao E2E와 release APK build는 통과했다. iOS 실제 로그인과
실기기 KakaoTalk 전환은 이번 범위 밖이며, 이 PC의 iOS `--no-codesign` build는
불완전한 Xcode·CocoaPods 환경 때문에 실행 전 차단됐다.

## 관련 문서

- [프로젝트 실행 방법](../README.md)
- [035 구현 결과](../docs/specs/035-kakao-auth-integration/implementation.md)
- [프론트엔드 컨벤션](../docs/conventions/frontend.md)
