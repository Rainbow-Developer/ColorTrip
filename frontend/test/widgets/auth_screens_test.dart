import 'dart:typed_data';
import 'dart:ui';

import 'package:colortrip/core/config/app_config.dart';
import 'package:colortrip/core/image_picking.dart';
import 'package:colortrip/core/network/dio_client.dart';
import 'package:colortrip/core/widgets/profile_image_picker.dart';
import 'package:colortrip/core/widgets/step_progress.dart';
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
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _user(OnboardingStep step) => UserProfile(
  id: 'user-id',
  nickname: step == OnboardingStep.profile ? '카카오닉네임' : '서버닉네임',
  birthDate: step == OnboardingStep.profile ? null : DateTime(2000, 1, 2),
  profileImage: null,
  dna: step == OnboardingStep.complete ? 'nature' : null,
  socialProvider: 'kakao',
  onboardingStep: step,
  isRestored: false,
);

UserProfile _withProfileImage(UserProfile user, String? profileImage) =>
    UserProfile(
      id: user.id,
      nickname: user.nickname,
      birthDate: user.birthDate,
      profileImage: profileImage,
      dna: user.dna,
      socialProvider: user.socialProvider,
      onboardingStep: user.onboardingStep,
      isRestored: user.isRestored,
    );

class _Repository implements AuthRepository {
  _Repository(this.user);

  UserProfile user;
  bool pending = false;
  int withdrawalCalls = 0;
  Object? loginError;
  Object? submitError;
  Object? updateError;
  Object? uploadImageError;
  final List<String> uploadedImages = [];
  int removeImageCalls = 0;

  /// 마지막으로 제출된 온보딩 입력 — 생년월일이 실제로 비어 전송되는지 확인한다.
  OnboardingProfileInput? submittedProfile;

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
    submittedProfile = input;
    if (submitError case final error?) throw error;
    return user = _user(OnboardingStep.tripDna);
  }

  @override
  Future<UserProfile> uploadProfileImage(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    if (uploadImageError case final error?) throw error;
    uploadedImages.add(mimeType);
    return user = _withProfileImage(user, '/uploads/avatars/2026/08/a.png');
  }

  @override
  Future<UserProfile> removeProfileImage() async {
    removeImageCalls++;
    return user = _withProfileImage(user, null);
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

/// 프로필 이미지 URL 해석이 `apiBaseUrl`을 필요로 하므로 테스트에서도 설정을 제공한다.
final _testConfig = AppConfig.fromValues(
  kakaoNativeAppKey: 'test-native-key',
  apiBaseUrl: 'https://api.example.com/api/v1',
);

Future<ProviderContainer> _container(_Repository repository) async {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(_testConfig),
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
    expect(find.text('이름'), findsNothing);
    // 이메일은 더 이상 수집하지 않으므로 입력 필드가 없어야 한다.
    expect(find.text('이메일'), findsNothing);
    expect(find.text('[필수] 이용약관 동의'), findsOneWidget);
    expect(find.text('[선택] 마케팅 수신 동의'), findsOneWidget);
  });

  testWidgets('signup uploads the picked profile image immediately', (
    tester,
  ) async {
    final repository = _Repository(_user(OnboardingStep.profile));
    final container = await _container(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ProfileImagePicker(
              imageUrl: null,
              isBusy: false,
              pickImage: (_) async =>
                  PickedImage(Uint8List.fromList([1, 2, 3]), 'image/png'),
              onPicked: (picked) => container
                  .read(authControllerProvider.notifier)
                  .uploadProfileImage(picked.bytes, mimeType: picked.mimeType),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ProfileImagePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('갤러리에서 선택'));
    await tester.pumpAndSettle();

    expect(repository.uploadedImages, ['image/png']);
    expect(
      container.read(authControllerProvider).user?.profileImage,
      '/uploads/avatars/2026/08/a.png',
    );
  });

  testWidgets('signup shows the optional profile image picker', (tester) async {
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

    expect(find.byType(ProfileImagePicker), findsOneWidget);
    expect(find.text('프로필 이미지 (선택)'), findsOneWidget);
  });

  testWidgets('edit profile replaces the static avatar with the picker', (
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

    expect(find.byType(ProfileImagePicker), findsOneWidget);
  });

  testWidgets('profile image picker hides removal when there is no image', (
    tester,
  ) async {
    final container = await _container(
      _Repository(_user(OnboardingStep.profile)),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ProfileImagePicker(
              imageUrl: null,
              onPicked: (_) async {},
              onRemoved: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ProfileImagePicker));
    await tester.pumpAndSettle();

    expect(find.text('갤러리에서 선택'), findsOneWidget);
    expect(find.text('기본 이미지로 변경'), findsNothing);
  });

  testWidgets('profile image picker removes an existing image', (tester) async {
    final repository = _Repository(_user(OnboardingStep.profile));
    final container = await _container(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ProfileImagePicker(
              imageUrl: 'https://api.example.com/uploads/avatars/a.png',
              onPicked: (_) async {},
              onRemoved: container
                  .read(authControllerProvider.notifier)
                  .removeProfileImage,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ProfileImagePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기본 이미지로 변경'));
    await tester.pumpAndSettle();

    expect(repository.removeImageCalls, 1);
  });

  testWidgets('signup birth date field opens a year/month/day wheel picker', (
    tester,
  ) async {
    // Material showDatePicker는 연도를 고르면 곧바로 일 달력으로 돌아가 월을 화살표로만
    // 넘길 수 있었다 — 연·월·일 휠로 교체했다(KAN-73).
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

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.text('생년월일을 선택해주세요'), findsOneWidget);
    // 연·월·일 휠 3개 — 월을 직접 고를 수 있다는 게 이번 변경의 핵심이다.
    expect(find.byType(CupertinoPicker), findsNWidgets(3));

    await tester.tap(find.text('선택 완료'));
    await tester.pumpAndSettle();
    // 선택 결과가 yyyy-MM-dd로 필드에 채워진다.
    final field = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(field.controller?.text, matches(r'^\d{4}-\d{2}-\d{2}$'));
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

  testWidgets('edit profile prefills server fields without an email row', (
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
    expect(find.text('2000-01-02'), findsOneWidget);
    expect(find.text('이름'), findsNothing);
    // 이메일은 더 이상 수집하지 않으므로 필드 자체가 없어야 한다.
    expect(find.text('이메일'), findsNothing);
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

  testWidgets('edit profile returns to the my tab after a successful save', (
    tester,
  ) async {
    // 저장 성공이 auth 상태를 바꾸면 GoRouter가 재평가돼 `/profile/edit`이 스택 없는
    // 단독 경로가 되고, 그때 `pop()`은 아무것도 하지 않아 수정 화면에 남는다.
    // 탭 경로로 직접 이동하는지 고정한다 — 경로는 '/profile'이 아니라 '/my'다.
    final container = await _container(
      _Repository(_user(OnboardingStep.complete)),
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/profile/edit',
      routes: [
        GoRoute(
          path: '/profile/edit',
          builder: (_, _) => const EditProfileScreen(),
        ),
        GoRoute(
          path: '/my',
          builder: (_, _) => const Scaffold(body: Text('마이 화면')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('마이 화면'), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsNothing);

    // 저장 토스트가 1.9초 뒤 스스로 사라진다 — 그 타이머를 남기면 테스트가 실패한다.
    await tester.pump(const Duration(seconds: 2));
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

  testWidgets('signup drops the step bar and requires a birth date', (
    tester,
  ) async {
    // 진행바는 회원가입에서 걷어내 여행 DNA 설문으로 옮겼다(2/3 고정이라 의미가 없었다 —
    // KAN-75). 생년월일은 이메일 폐지와 함께 다시 필수가 됐다(KAN-74) — 비운 채 제출하면
    // 서버로 넘어가지 않고 필드 오류가 뜬다.
    final repository = _Repository(_user(OnboardingStep.profile));
    final container = await _container(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SignupScreen()),
      ),
    );

    expect(find.byType(StepProgress), findsNothing);
    expect(find.text('생년월일'), findsOneWidget);
    expect(find.text('생년월일 (선택)'), findsNothing);

    await tester.tap(find.text('[필수] 이용약관 동의'));
    await tester.tap(find.text('[필수] 개인정보 처리방침'));
    await tester.pump();
    await tester.ensureVisible(find.text('다음'));
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.textContaining('생년월일'), findsWidgets);
    expect(repository.submittedProfile, isNull);
  });
}
