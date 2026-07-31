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
