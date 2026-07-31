import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dio 클라이언트 — 지도 동기화·여행 DNA·홈 추천·퀘스트 인증 Repository가 이 인스턴스로
/// `/api/v1`을 호출한다. 나머지 기능은 아직 정적 데이터를 쓴다([000-frontend-app] 참고).
///
/// Authorization은 개발용 하드코딩 토큰이다 — Kakao 로그인 연동(KAN-53/54) 후 교체 대상이다.
/// 토큰의 `sub` 사용자가 로컬/dev DB에 있어야 보호 API가 200을 준다
/// (`backend/generate_dev_token.py`로 재발급).
///
/// Android 에뮬레이터에서는 10.0.2.2가 호스트 머신 루프백을 가리킨다
/// (실기기는 같은 Wi-Fi의 LAN IP로 바꿔야 한다 — frontend/README.md).
final _apiHost = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
    ? '10.0.2.2'
    : 'localhost';

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: 'http://$_apiHost:8000/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Authorization':
            'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwMTlmNTVkMS1iMTMyLTc2YjItOWE0Mi02OTM0YzU2NGJiNWEiLCJ0eXBlIjoiYWNjZXNzIiwiaWF0IjoxNzg1MzMwOTIxLCJleHAiOjE3ODU5MzU3MjF9.zQxaDz9upLqDzeaWgfJOEiEFh1z4blK2eALvkx7WXkA',
      },
    ),
  );
});
