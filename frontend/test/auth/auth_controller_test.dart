import 'dart:async';

import 'package:colortrip/data/auth/kakao_auth_gateway.dart';
import 'package:colortrip/data/models/auth_models.dart';
import 'package:colortrip/data/repositories/auth_repository.dart';
import 'package:colortrip/state/auth_controller.dart';
import 'package:colortrip/state/repository_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _user(OnboardingStep step) => UserProfile(
  id: 'user-id',
  email: step == OnboardingStep.profile ? null : 'traveler@example.com',
  nickname: step == OnboardingStep.profile ? null : '컬러트립',
  birthDate: step == OnboardingStep.profile ? null : DateTime(2000, 1, 2),
  profileImage: null,
  dna: step == OnboardingStep.complete ? 'nature' : null,
  socialProvider: 'kakao',
  onboardingStep: step,
  isRestored: false,
);

class _Repository implements AuthRepository {
  UserProfile? restored;
  UserProfile loginUser = _user(OnboardingStep.profile);
  UserProfile submittedUser = _user(OnboardingStep.tripDna);
  bool pending = false;
  Object? loginError;
  Object? withdrawalError;
  Object? restoreError;
  Object? submitError;
  Completer<UserProfile>? submitCompleter;

  @override
  Future<UserProfile> fetchCurrentUser() async => loginUser;

  @override
  Future<bool> isWithdrawalPending() async => pending;

  @override
  Future<AuthSession> loginWithKakao() async {
    if (loginError case final error?) throw error;
    return AuthSession(
      tokens: const TokenPair(accessToken: 'access', refreshToken: 'refresh'),
      user: loginUser,
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<UserProfile?> restoreSession() async {
    if (restoreError case final error?) throw error;
    return restored;
  }

  @override
  Future<UserProfile> submitOnboardingProfile(
    OnboardingProfileInput input,
  ) async {
    if (submitError case final error?) throw error;
    return submitCompleter?.future ?? submittedUser;
  }

  @override
  Future<UserProfile> updateProfile(ProfileUpdateInput input) async =>
      submittedUser;

  @override
  Future<void> withdraw() async {
    if (withdrawalError case final error?) {
      pending = true;
      throw error;
    }
  }
}

void main() {
  test('bootstrap maps server onboarding step to auth state', () async {
    final repository = _Repository()..restored = _user(OnboardingStep.tripDna);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).bootstrap();

    expect(
      container.read(authControllerProvider).status,
      AuthStatus.tripDnaRequired,
    );
    expect(container.read(currentUserProvider)?.nickname, '컬러트립');
  });

  test(
    'cancelled Kakao login stays unauthenticated without an error',
    () async {
      final repository = _Repository()
        ..loginError = const KakaoLoginCancelled();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).login();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(container.read(authControllerProvider).errorMessage, isNull);
    },
  );

  test('login errors distinguish timeout network backend and SDK setup', () {
    final request = RequestOptions(path: '/auth/login/social');

    expect(
      authLoginErrorMessage(
        DioException(
          requestOptions: request,
          type: DioExceptionType.connectionTimeout,
        ),
      ),
      contains('시간'),
    );
    expect(
      authLoginErrorMessage(
        DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
        ),
      ),
      contains('네트워크'),
    );
    expect(
      authLoginErrorMessage(
        DioException(
          requestOptions: request,
          response: Response(
            requestOptions: request,
            statusCode: 401,
            data: {'code': 'SOCIAL_AUTH_ERROR'},
          ),
        ),
      ),
      contains('카카오 인증'),
    );
    expect(
      authLoginErrorMessage(PlatformException(code: 'SDK_NOT_INITIALIZED')),
      contains('설정'),
    );
    expect(
      authLoginErrorMessage(
        const KakaoLoginFailure(KakaoLoginFailureReason.platformMisconfigured),
      ),
      allOf(contains('패키지'), contains('키 해시')),
    );
    expect(
      authLoginErrorMessage(
        const KakaoLoginFailure(KakaoLoginFailureReason.invalidClient),
      ),
      contains('Native App Key'),
    );
  });

  test(
    'failed backend withdrawal exposes retry state and keeps user',
    () async {
      final repository = _Repository()
        ..restored = _user(OnboardingStep.complete)
        ..withdrawalError = StateError('backend unavailable');
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.notifier).bootstrap();

      await container.read(authControllerProvider.notifier).withdraw();

      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.withdrawalPending);
      expect(state.user, isNotNull);
      expect(state.errorMessage, isNotNull);
    },
  );

  test(
    'bootstrap exposes transient restore failure without losing retry',
    () async {
      final repository = _Repository()
        ..restoreError = StateError('network unavailable');
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).bootstrap();

      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.failure);
      expect(state.errorMessage, isNotNull);
    },
  );

  test(
    'bootstrap keeps a withdrawal marker without a recoverable JWT',
    () async {
      final repository = _Repository()
        ..pending = true
        ..restored = null;
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).bootstrap();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.withdrawalPending,
      );
      expect(container.read(authControllerProvider).user, isNull);
    },
  );

  test('session expiry wins over a late onboarding failure', () async {
    final completion = Completer<UserProfile>();
    final repository = _Repository()
      ..restored = _user(OnboardingStep.profile)
      ..submitCompleter = completion;
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);
    await controller.bootstrap();

    final submission = controller.submitOnboardingProfile(
      OnboardingProfileInput(
        nickname: '컬러트립',
        email: 'traveler@example.com',
        birthDate: DateTime(2000, 1, 2),
        termsAgreed: true,
        privacyAgreed: true,
        marketingAgreed: false,
      ),
    );
    controller.sessionExpired();
    completion.completeError(StateError('late failure'));
    await submission;

    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );
  });

  test('recovers onboarding when the success response was lost', () async {
    final repository = _Repository()
      ..restored = _user(OnboardingStep.profile)
      ..loginUser = _user(OnboardingStep.tripDna)
      ..submitError = StateError('response connection lost');
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);
    await controller.bootstrap();

    final success = await controller.submitOnboardingProfile(
      OnboardingProfileInput(
        nickname: '컬러트립',
        email: 'traveler@example.com',
        birthDate: DateTime(2000, 1, 2),
        termsAgreed: true,
        privacyAgreed: true,
        marketingAgreed: false,
      ),
    );

    expect(success, isTrue);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.tripDnaRequired,
    );
  });
}
