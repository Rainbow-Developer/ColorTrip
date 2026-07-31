import 'dart:ui';

import 'package:colortrip/data/models/auth_models.dart';
import 'package:colortrip/data/repositories/auth_repository.dart';
import 'package:colortrip/features/onboarding/config_error_app.dart';
import 'package:colortrip/features/onboarding/signup_screen.dart';
import 'package:colortrip/features/onboarding/splash_screen.dart';
import 'package:colortrip/features/profile/profile_screen.dart';
import 'package:colortrip/features/profile/edit_profile_screen.dart';
import 'package:colortrip/features/profile/withdrawal_pending_screen.dart';
import 'package:colortrip/state/auth_controller.dart';
import 'package:colortrip/state/onboarding_tour_notifier.dart';
import 'package:colortrip/state/progress_notifier.dart';
import 'package:colortrip/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _user(OnboardingStep step) => UserProfile(
  id: 'user-id',
  email: step == OnboardingStep.profile
      ? 'kakao@example.com'
      : 'user@example.com',
  nickname: step == OnboardingStep.profile ? '카카오닉네임' : '서버닉네임',
  birthDate: step == OnboardingStep.profile ? null : DateTime(2000, 1, 2),
  profileImage: null,
  dna: step == OnboardingStep.complete ? 'nature' : null,
  socialProvider: 'kakao',
  onboardingStep: step,
  isRestored: false,
);

class _Repository implements AuthRepository {
  _Repository(this.user);

  UserProfile user;
  bool pending = false;
  int withdrawalCalls = 0;
  Object? loginError;
  Object? submitError;
  Object? updateError;

  @override
  Future<UserProfile> fetchCurrentUser() async => user;

  @override
  Future<bool> isWithdrawalPending() async => pending;

  @override
  Future<AuthSession> loginWithKakao() async {
    if (loginError case final error?) throw error;
    return AuthSession(
      tokens: const TokenPair(accessToken: 'access', refreshToken: 'refresh'),
      user: user,
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<UserProfile?> restoreSession() async => user;

  @override
  Future<UserProfile> submitOnboardingProfile(
    OnboardingProfileInput input,
  ) async {
    if (submitError case final error?) throw error;
    return user = _user(OnboardingStep.tripDna);
  }

  @override
  Future<UserProfile> updateProfile(ProfileUpdateInput input) async {
    if (updateError case final error?) throw error;
    return user;
  }

  @override
  Future<void> withdraw() async {
    withdrawalCalls++;
  }
}

Future<ProviderContainer> _container(_Repository repository) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      onboardingTourProvider.overrideWith(
        () => OnboardingTourNotifier(
          const OnboardingTourState(step: 3, skipped: true),
        ),
      ),
    ],
  );
  await container.read(authControllerProvider.notifier).bootstrap();
  return container;
}

void main() {
  testWidgets('splash hides login action while restoring the session', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          _Repository(_user(OnboardingStep.profile)),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SplashScreen()),
      ),
    );

    expect(find.text('카카오로 시작하기'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('configuration failure names missing build definitions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ConfigErrorApp(
        message: 'Missing KAKAO_NATIVE_APP_KEY and API_BASE_URL',
      ),
    );

    expect(find.text('개발 설정을 확인해주세요'), findsOneWidget);
    expect(find.textContaining('KAKAO_NATIVE_APP_KEY'), findsOneWidget);
    expect(find.textContaining('API_BASE_URL'), findsOneWidget);
  });

  testWidgets('signup prefills server-verified Kakao values and omits name', (
    tester,
  ) async {
    final container = await _container(
      _Repository(_user(OnboardingStep.profile)),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SignupScreen()),
      ),
    );

    expect(find.text('카카오닉네임'), findsOneWidget);
    expect(find.text('kakao@example.com'), findsOneWidget);
    expect(find.text('이름'), findsNothing);
    expect(find.text('[필수] 이용약관 동의'), findsOneWidget);
    expect(find.text('[선택] 마케팅 수신 동의'), findsOneWidget);
  });

  testWidgets('signup birth date field opens a date picker', (tester) async {
    final container = await _container(
      _Repository(_user(OnboardingStep.profile)),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SignupScreen()),
      ),
    );
    await tester.tap(find.widgetWithText(TextField, '2000-01-01'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('signup agreements expose checked semantics', (tester) async {
    final container = await _container(
      _Repository(_user(OnboardingStep.profile)),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SignupScreen()),
      ),
    );
    final agreement = find.bySemanticsLabel('[필수] 이용약관 동의');
    expect(agreement, findsOneWidget);
    await tester.tap(agreement);
    await tester.pump();

    expect(
      tester.getSemantics(agreement).flagsCollection.isChecked,
      CheckedState.isTrue,
    );
  });

  testWidgets('signup back asks before abandoning onboarding', (tester) async {
    final container = await _container(
      _Repository(_user(OnboardingStep.profile)),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SignupScreen()),
      ),
    );
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.text('회원가입을 중단할까요?'), findsOneWidget);
    expect(find.text('계속 작성'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
  });

  testWidgets('signup system back also asks before abandoning onboarding', (
    tester,
  ) async {
    final container = await _container(
      _Repository(_user(OnboardingStep.profile)),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SignupScreen()),
      ),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('회원가입을 중단할까요?'), findsOneWidget);
    expect(find.text('계속 작성'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
  });

  testWidgets('signup shows a user-facing error when saving fails', (
    tester,
  ) async {
    final profile = UserProfile(
      id: 'user-id',
      email: 'kakao@example.com',
      nickname: '카카오닉네임',
      birthDate: DateTime(2000, 1, 2),
      profileImage: null,
      dna: null,
      socialProvider: 'kakao',
      onboardingStep: OnboardingStep.profile,
      isRestored: false,
    );
    final repository = _Repository(profile)
      ..submitError = StateError('backend unavailable');
    final container = await _container(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SignupScreen()),
      ),
    );
    await tester.tap(find.text('[필수] 이용약관 동의'));
    await tester.tap(find.text('[필수] 개인정보 처리방침'));
    await tester.pump();
    await tester.ensureVisible(find.text('다음'));
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.textContaining('기본 정보를 저장하지 못했습니다'), findsOneWidget);
  });

  testWidgets('login failure stays on splash and shows retryable error UX', (
    tester,
  ) async {
    final repository = _Repository(_user(OnboardingStep.profile))
      ..loginError = StateError('network unavailable');
    final container = await _container(repository);
    container.read(authControllerProvider.notifier).sessionExpired();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pump();

    expect(find.textContaining('카카오 로그인에 실패했습니다'), findsOneWidget);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
  });

  testWidgets(
    'profile uses the server user instead of local progress nickname',
    (tester) async {
      final container = await _container(
        _Repository(_user(OnboardingStep.complete)),
      );
      container.read(progressProvider.notifier).setNickname('로컬닉네임');
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );

      expect(find.text('서버닉네임'), findsOneWidget);
      expect(find.text('로컬닉네임'), findsNothing);
      expect(find.text('로그아웃'), findsOneWidget);
    },
  );

  testWidgets('edit profile prefills server fields and keeps email read-only', (
    tester,
  ) async {
    final container = await _container(
      _Repository(_user(OnboardingStep.complete)),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditProfileScreen()),
      ),
    );

    expect(find.text('서버닉네임'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.text('2000-01-02'), findsOneWidget);
    expect(find.text('이름'), findsNothing);
    final emailField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'user@example.com'),
    );
    expect(emailField.enabled, isFalse);
  });

  testWidgets('edit profile shows a user-facing error when saving fails', (
    tester,
  ) async {
    final repository = _Repository(_user(OnboardingStep.complete))
      ..updateError = StateError('backend unavailable');
    final container = await _container(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditProfileScreen()),
      ),
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.textContaining('프로필을 저장하지 못했습니다'), findsOneWidget);
  });

  testWidgets('withdrawal pending screen offers a real retry action', (
    tester,
  ) async {
    final repository = _Repository(_user(OnboardingStep.complete))
      ..pending = true;
    final container = await _container(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WithdrawalPendingScreen()),
      ),
    );
    await tester.tap(find.text('탈퇴 다시 시도'));
    await tester.pump();

    expect(repository.withdrawalCalls, 1);
  });
}
