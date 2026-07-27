import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

abstract interface class KakaoAuthGateway {
  Future<String> login();
  Future<void> logout();
  Future<void> unlink();
}

class KakaoLoginCancelled implements Exception {
  const KakaoLoginCancelled();
}

enum KakaoLoginFailureReason {
  platformMisconfigured,
  invalidClient,
  invalidScope,
  unauthorized,
  network,
  server,
  sdk,
  unknown,
}

class KakaoLoginFailure implements Exception {
  const KakaoLoginFailure(this.reason);

  final KakaoLoginFailureReason reason;
}

abstract interface class KakaoSdkClient {
  Future<bool> isTalkInstalled();
  Future<String> loginWithTalk();
  Future<String> loginWithAccount();
  Future<void> logout();
  Future<void> unlink();
}

class KakaoSdkClientAdapter implements KakaoSdkClient {
  const KakaoSdkClientAdapter();

  @override
  Future<bool> isTalkInstalled() => isKakaoTalkInstalled();

  @override
  Future<String> loginWithTalk() async =>
      (await UserApi.instance.loginWithKakaoTalk()).accessToken;

  @override
  Future<String> loginWithAccount() async =>
      (await UserApi.instance.loginWithKakaoAccount()).accessToken;

  @override
  Future<void> logout() => UserApi.instance.logout();

  @override
  Future<void> unlink() => UserApi.instance.unlink();
}

class KakaoSdkAuthGateway implements KakaoAuthGateway {
  const KakaoSdkAuthGateway({this.client = const KakaoSdkClientAdapter()});

  final KakaoSdkClient client;

  @override
  Future<String> login() async {
    try {
      if (await client.isTalkInstalled()) {
        try {
          return await client.loginWithTalk();
        } on Object catch (error) {
          if (_isCancellation(error)) rethrow;
        }
      }
      return await client.loginWithAccount();
    } on Object catch (error) {
      if (_isCancellation(error)) {
        throw const KakaoLoginCancelled();
      }
      throw KakaoLoginFailure(_classifyFailure(error));
    }
  }

  @override
  Future<void> logout() async {
    await client.logout();
  }

  @override
  Future<void> unlink() async {
    try {
      await client.unlink();
    } on KakaoClientException catch (error) {
      if (error.reason != ClientErrorCause.tokenNotFound) rethrow;
    } on KakaoApiException catch (error) {
      if (error.code != ApiErrorCause.invalidToken &&
          error.code != ApiErrorCause.notRegisteredUser) {
        rethrow;
      }
    }
  }

  bool _isCancellation(Object error) =>
      error is PlatformException &&
          const {'CANCELED', 'CANCELLED'}.contains(error.code.toUpperCase()) ||
      error is KakaoClientException &&
          error.reason == ClientErrorCause.cancelled ||
      error is KakaoAuthException &&
          error.error == AuthErrorCause.accessDenied ||
      error is KakaoApiException && error.code == ApiErrorCause.accessDenied;

  KakaoLoginFailureReason _classifyFailure(Object error) {
    if (error is KakaoAuthException) {
      return switch (error.error) {
        AuthErrorCause.misconfigured =>
          KakaoLoginFailureReason.platformMisconfigured,
        AuthErrorCause.invalidClient => KakaoLoginFailureReason.invalidClient,
        AuthErrorCause.invalidScope => KakaoLoginFailureReason.invalidScope,
        AuthErrorCause.unauthorized => KakaoLoginFailureReason.unauthorized,
        AuthErrorCause.serverError => KakaoLoginFailureReason.server,
        AuthErrorCause.invalidRequest ||
        AuthErrorCause.invalidGrant ||
        AuthErrorCause.accessDenied ||
        AuthErrorCause.unknown => KakaoLoginFailureReason.unknown,
      };
    }
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError => KakaoLoginFailureReason.network,
        DioExceptionType.badResponse
            when (error.response?.statusCode ?? 0) >= 500 =>
          KakaoLoginFailureReason.server,
        _ => KakaoLoginFailureReason.unknown,
      };
    }
    if (error is PlatformException || error is KakaoClientException) {
      return KakaoLoginFailureReason.sdk;
    }
    return KakaoLoginFailureReason.unknown;
  }
}
