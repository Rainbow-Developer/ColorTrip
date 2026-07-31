import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, kReleaseMode, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dio 클라이언트 — 지도 동기화·여행 DNA·홈 추천·퀘스트 인증 Repository가 이 인스턴스로
/// `/api/v1`을 호출한다. 나머지 기능은 아직 정적 데이터를 쓴다([000-frontend-app] 참고).
///
/// Authorization은 개발용 하드코딩 토큰이다 — Kakao 로그인 연동(KAN-53/54) 후 교체 대상이다.
/// 토큰의 `sub` 사용자가 로컬/dev DB에 있어야 보호 API가 200을 준다
/// (`backend/generate_dev_token.py`로 재발급).
///
/// API 주소는 빌드 시 주입할 수 있다 — 실기기는 에뮬레이터 루프백(10.0.2.2)에 붙을 수 없어
/// 재빌드 없이 주소를 바꿀 수 있어야 한다(frontend/README.md '실기기 설치').
///
///   flutter build apk --release --dart-define=API_BASE_URL=http://192.168.0.3:8000/api/v1
///
/// 미지정 시 기본값은 빌드 모드로 갈린다 — `TargetPlatform.android`는 에뮬레이터와 실기기를
/// 구분하지 못하므로, 설치해서 쓰는 release 빌드가 조용히 기기 루프백(10.0.2.2)을 향하면
/// 원인을 찾기 어려운 연결 실패가 된다.
///
/// - release: 팀 dev 서버 (설치용 APK가 주소 없이도 동작하도록)
/// - debug/profile: Android는 에뮬레이터 루프백(10.0.2.2), 그 외는 localhost
const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

/// 팀 dev 서버 — 규약: docs/conventions/infra-deploy.md
const _devServerBaseUrl = 'http://34.64.226.70/api/v1';

final _localBaseUrl = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
    ? 'http://10.0.2.2:8000/api/v1' // Android 에뮬레이터에서 호스트 머신 루프백
    : 'http://localhost:8000/api/v1';

final _apiBaseUrl = _apiBaseUrlOverride.isNotEmpty
    ? _apiBaseUrlOverride
    : (kReleaseMode ? _devServerBaseUrl : _localBaseUrl);

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: _apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Authorization':
            'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwMTlmNTVkMS1iMTMyLTc2YjItOWE0Mi02OTM0YzU2NGJiNWEiLCJ0eXBlIjoiYWNjZXNzIiwiaWF0IjoxNzg1MzMwOTIxLCJleHAiOjE3ODU5MzU3MjF9.zQxaDz9upLqDzeaWgfJOEiEFh1z4blK2eALvkx7WXkA',
      },
    ),
  );
});
