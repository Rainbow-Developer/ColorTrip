class AppConfig {
  const AppConfig._({
    required this.kakaoNativeAppKey,
    required this.apiBaseUrl,
  });

  factory AppConfig.fromBuildEnvironment() => AppConfig.fromValues(
    kakaoNativeAppKey: const String.fromEnvironment('KAKAO_NATIVE_APP_KEY'),
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
  );

  factory AppConfig.fromValues({
    required String kakaoNativeAppKey,
    required String apiBaseUrl,
  }) {
    final nativeKey = kakaoNativeAppKey.trim();
    final baseUrl = apiBaseUrl.trim();
    if (nativeKey.isEmpty && baseUrl.isEmpty) {
      throw StateError(
        'Missing KAKAO_NATIVE_APP_KEY and API_BASE_URL build definitions. '
        'Pass both with --dart-define.',
      );
    }
    if (nativeKey.isEmpty) {
      throw StateError(
        'Missing KAKAO_NATIVE_APP_KEY build definition. '
        'Pass it with --dart-define.',
      );
    }
    if (baseUrl.isEmpty) {
      throw StateError(
        'Missing API_BASE_URL build definition. Pass it with --dart-define.',
      );
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw StateError('API_BASE_URL must be an absolute HTTP(S) URL.');
    }
    return AppConfig._(
      kakaoNativeAppKey: nativeKey,
      apiBaseUrl: baseUrl.replaceFirst(RegExp(r'/$'), ''),
    );
  }

  final String kakaoNativeAppKey;
  final String apiBaseUrl;
}
