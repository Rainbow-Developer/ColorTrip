import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/auth/kakao_auth_gateway.dart';
import '../../data/auth/secure_token_storage.dart';
import '../config/app_config.dart';
import 'auth_session_interceptor.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('main.dart must provide AppConfig.'),
);

/// 서버가 주는 업로드 URL을 화면에서 바로 쓸 수 있는 절대 URL로 바꾼다.
///
/// 로컬 스토리지는 `/uploads/...` 상대 경로를, GCS와 Kakao CDN은 절대 URL을 돌려준다.
/// [Uri.resolve]는 절대 URL을 그대로 통과시키고 절대 경로만 `apiBaseUrl`의 origin에
/// 붙이므로 세 경우를 한 번에 처리한다 (docs/specs/080-profile-image).
final resolveUploadUrlProvider = Provider<String? Function(String?)>((ref) {
  final base = Uri.parse(ref.watch(appConfigProvider).apiBaseUrl);
  return (url) =>
      (url == null || url.trim().isEmpty) ? null : base.resolve(url).toString();
});

final sessionExpiredCallbackProvider = Provider<void Function()>(
  (ref) => () {},
);

final onboardingRequiredCallbackProvider = Provider<void Function()>(
  (ref) => () {},
);

final kakaoAuthGatewayProvider = Provider<KakaoAuthGateway>(
  (ref) => const KakaoSdkAuthGateway(),
);

final secureTokenStorageProvider = Provider<SecureTokenStorage>(
  (ref) => JsonSecureTokenStorage(
    FlutterSecureKeyValueStore(
      FlutterSecureStorage(
        aOptions: AndroidOptions(resetOnError: true),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      ),
    ),
  ),
);

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final storage = ref.watch(secureTokenStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  final refreshDio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  dio.interceptors.add(
    AuthSessionInterceptor(
      client: dio,
      refreshClient: refreshDio,
      storage: storage,
      onSessionExpired: () => ref.read(sessionExpiredCallbackProvider)(),
      onOnboardingRequired: () =>
          ref.read(onboardingRequiredCallbackProvider)(),
    ),
  );
  ref.onDispose(() {
    dio.close(force: true);
    refreshDio.close(force: true);
  });
  return dio;
});
