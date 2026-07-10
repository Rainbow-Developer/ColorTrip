import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dio 클라이언트 — 설정만 해두고 실제 API 호출은 하지 않는다(백엔드 연동 전, [plan.md] 비목표).
/// 후속 연동 시 Repository 구현체가 이 인스턴스를 사용해 실제 엔드포인트를 호출한다.
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8000/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
});
