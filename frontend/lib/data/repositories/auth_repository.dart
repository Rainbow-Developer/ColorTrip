import 'package:dio/dio.dart';

import '../auth/kakao_auth_gateway.dart';
import '../auth/secure_token_storage.dart';
import '../models/auth_models.dart';

abstract class AuthRepository {
  Future<AuthSession> loginWithKakao();
  Future<bool> isWithdrawalPending();
  Future<UserProfile?> restoreSession();
  Future<UserProfile> fetchCurrentUser();
  Future<UserProfile> submitOnboardingProfile(OnboardingProfileInput input);
  Future<UserProfile> updateProfile(ProfileUpdateInput input);
  Future<void> logout();
  Future<void> withdraw();
}

class DioAuthRepository implements AuthRepository {
  const DioAuthRepository({
    required this.dio,
    required this.kakao,
    required this.storage,
    this.logoutAttempts = 2,
  });

  final Dio dio;
  final KakaoAuthGateway kakao;
  final SecureTokenStorage storage;
  final int logoutAttempts;

  @override
  Future<bool> isWithdrawalPending() => storage.isWithdrawalPending();

  @override
  Future<AuthSession> loginWithKakao() async {
    final kakaoAccessToken = await kakao.login();
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/login/social',
      data: {'provider': 'kakao', 'access_token': kakaoAccessToken},
      options: Options(extra: {'requiresAuth': false}),
    );
    final session = AuthSession.fromJson(_data(response));
    await storage.replace(session.tokens, preserveWithdrawalState: false);
    return session;
  }

  @override
  Future<UserProfile?> restoreSession() async {
    if (await storage.read() == null) return null;
    return fetchCurrentUser();
  }

  @override
  Future<UserProfile> fetchCurrentUser() async {
    final response = await dio.get<Map<String, dynamic>>('/users/me');
    return UserProfile.fromJson(_data(response));
  }

  @override
  Future<UserProfile> submitOnboardingProfile(
    OnboardingProfileInput input,
  ) async {
    final response = await dio.put<Map<String, dynamic>>(
      '/users/me/onboarding-profile',
      data: input.toJson(),
    );
    return UserProfile.fromJson(_data(response));
  }

  @override
  Future<UserProfile> updateProfile(ProfileUpdateInput input) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '/users/me',
      data: input.toJson(),
    );
    return UserProfile.fromJson(_data(response));
  }

  @override
  Future<void> logout() async {
    try {
      for (var attempt = 0; attempt < logoutAttempts; attempt++) {
        try {
          final tokens = await storage.read();
          if (tokens != null) {
            await dio.post<void>(
              '/auth/logout',
              data: {'refresh_token': tokens.refreshToken},
            );
          }
          break;
        } on DioException {
          // Re-read storage on the next attempt because a 401 interceptor may
          // have rotated both tokens while this request was in flight.
        }
      }
      try {
        await kakao.logout();
      } on Object {
        // Kakao logout is best-effort. The local device session is authoritative.
      }
    } finally {
      await storage.clear();
    }
  }

  @override
  Future<void> withdraw() async {
    final stage = await storage.withdrawalStage();
    if (stage != WithdrawalStage.backendPending) {
      if (stage == WithdrawalStage.none) {
        await storage.markWithdrawalUnlinkPending();
      }
      await kakao.unlink();
      await storage.markWithdrawalPending();
    }
    await dio.delete<void>('/users/me');
    await storage.clear();
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) {
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid API response envelope.');
    }
    return data;
  }
}
