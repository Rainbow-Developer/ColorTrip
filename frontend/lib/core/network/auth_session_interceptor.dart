import 'dart:async';

import 'package:dio/dio.dart';

import '../../data/auth/secure_token_storage.dart';
import '../../data/models/auth_models.dart';

class AuthRequestNotReplayable implements Exception {
  const AuthRequestNotReplayable();

  @override
  String toString() =>
      'The authenticated request body cannot be replayed after token refresh.';
}

class AuthSessionInterceptor extends Interceptor {
  AuthSessionInterceptor({
    required this.client,
    required this.refreshClient,
    required this.storage,
    required this.onSessionExpired,
    void Function()? onOnboardingRequired,
  }) : onOnboardingRequired = onOnboardingRequired ?? _noop;

  static const _retriedKey = 'colortrip.auth.retried';

  final Dio client;
  final Dio refreshClient;
  final SecureTokenStorage storage;
  final void Function() onSessionExpired;
  final void Function() onOnboardingRequired;
  Future<bool>? _refreshInFlight;
  String? _lastRotatedAccessToken;
  String? _lastReplacementAccessToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['requiresAuth'] != false) {
      final tokens = await storage.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode == 403 &&
        _responseCode(err.response?.data) == 'ONBOARDING_REQUIRED') {
      onOnboardingRequired();
      handler.next(err);
      return;
    }
    if (err.response?.statusCode != 401 ||
        options.extra[_retriedKey] == true ||
        options.extra['requiresAuth'] == false) {
      handler.next(err);
      return;
    }

    final currentBeforeRefresh = await storage.read();
    final failedAuthorization = options.headers['Authorization'];
    final tokensAlreadyRotated =
        currentBeforeRefresh != null &&
        failedAuthorization is String &&
        failedAuthorization == 'Bearer $_lastRotatedAccessToken' &&
        currentBeforeRefresh.accessToken == _lastReplacementAccessToken;
    final refreshed = tokensAlreadyRotated || await _sharedRefresh();
    if (!refreshed) {
      handler.next(err);
      return;
    }

    if (options.data is FormData) {
      handler.next(
        DioException(
          requestOptions: options,
          response: err.response,
          type: DioExceptionType.unknown,
          error: const AuthRequestNotReplayable(),
        ),
      );
      return;
    }

    try {
      final tokens = await storage.read();
      if (tokens == null) {
        handler.next(err);
        return;
      }
      options.extra[_retriedKey] = true;
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      handler.resolve(await client.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      if (retryError.response?.statusCode == 401) {
        final current = await storage.read();
        if (current != null) {
          await _expireSession(current.refreshToken);
        }
      }
      handler.next(retryError);
    }
  }

  static String? _responseCode(Object? responseData) {
    if (responseData is Map<String, dynamic>) {
      return responseData['code'] as String?;
    }
    return null;
  }

  static void _noop() {}

  Future<bool> _sharedRefresh() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final refresh = _refresh();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<bool> _refresh() async {
    final current = await storage.read();
    if (current == null) return false;
    try {
      final response = await refreshClient.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': current.refreshToken},
        options: Options(extra: {'requiresAuth': false}),
      );
      final envelope = response.data;
      final data = envelope?['data'];
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid refresh response.');
      }
      final replacement = TokenPair.fromJson(data);
      final replaced = await storage.replaceIfRefreshToken(
        current.refreshToken,
        replacement,
      );
      if (replaced) {
        _lastRotatedAccessToken = current.accessToken;
        _lastReplacementAccessToken = replacement.accessToken;
      }
      return replaced;
    } on Object {
      await _expireSession(current.refreshToken);
      return false;
    }
  }

  Future<void> _expireSession(String expectedRefreshToken) async {
    if (await storage.clearIfRefreshToken(expectedRefreshToken)) {
      onSessionExpired();
    }
  }
}
