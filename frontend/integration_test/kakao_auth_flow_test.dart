import 'dart:typed_data';

import 'package:colortrip/data/models/auth_models.dart';
import 'package:colortrip/data/models/map_region_progress.dart';
import 'package:colortrip/data/models/trip_dna_question.dart';
import 'package:colortrip/data/repositories/auth_repository.dart';
import 'package:colortrip/data/repositories/domain_repository.dart';
import 'package:colortrip/data/repositories/map_repository.dart';
import 'package:colortrip/data/repositories/trip_dna_repository.dart';
import 'package:colortrip/main.dart';
import 'package:colortrip/state/auth_controller.dart';
import 'package:colortrip/state/onboarding_tour_notifier.dart';
import 'package:colortrip/state/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

UserProfile _profile(OnboardingStep step) => UserProfile(
  id: 'integration-user',
  nickname: '통합여행자',
  birthDate: DateTime(2000, 1, 2),
  profileImage: null,
  dna: step == OnboardingStep.complete ? 'activity' : null,
  socialProvider: 'kakao',
  onboardingStep: step,
  isRestored: false,
);

class _AuthRepository implements AuthRepository {
  UserProfile? user;

  @override
  Future<UserProfile> fetchCurrentUser() async => user!;

  @override
  Future<bool> isWithdrawalPending() async => false;

  @override
  Future<AuthSession> loginWithKakao() async {
    user = _profile(OnboardingStep.profile);
    return AuthSession(
      tokens: const TokenPair(
        accessToken: 'integration-access',
        refreshToken: 'integration-refresh',
      ),
      user: user!,
    );
  }

  @override
  Future<void> logout() async => user = null;

  @override
  Future<UserProfile?> restoreSession() async => user;

  @override
  Future<UserProfile> submitOnboardingProfile(
    OnboardingProfileInput input,
  ) async => user = _profile(OnboardingStep.tripDna);

  @override
  Future<UserProfile> uploadProfileImage(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async => user!;

  @override
  Future<UserProfile> removeProfileImage() async => user!;

  @override
  Future<UserProfile> updateProfile(ProfileUpdateInput input) async => user!;

  @override
  Future<void> withdraw() async => user = null;
}

class _TripDnaRepository implements TripDnaRepository {
  _TripDnaRepository(this.auth);

  final _AuthRepository auth;

  @override
  Future<List<TripDnaQuestion>> questions() async => const [
    TripDnaQuestion(
      id: 'question-1',
      question: '어떤 여행을 좋아하나요?',
      options: [TripDnaOption(id: 'option-1', label: '액티비티를 즐겨요')],
    ),
  ];

  @override
  Future<Map<String, dynamic>> submitReplies(
    List<Map<String, String>> replies,
  ) async {
    auth.user = _profile(OnboardingStep.complete);
    return {
      'main_dna_type': 'activity',
      'scores': {'activity': 1},
    };
  }
}

class _MapRepository implements MapRepository {
  @override
  Future<List<MapRegionProgress>> fetchMyMap() async => const [];
}

class _DomainRepository implements DomainRepository {
  @override
  Future<DomainSnapshot> fetchSnapshot() async => const DomainSnapshot(
    catalog: DomainCatalog(
      regionIdsByKey: {},
      regionKeysById: {},
      questIdsByKey: {},
      questKeysById: {},
    ),
    journeys: [],
    completedQuestKeys: {},
    regionProgress: {},
    regionTripCount: {},
    timeline: [],
  );

  @override
  Future<List<DomainRecommendedRegion>>
  fetchUnvisitedRecommendedRegions() async => const [];

  @override
  Future<List<String>> fetchRecommendedQuestKeys({
    required String regionKey,
    int size = 2,
  }) async => const [];

  @override
  Future<DomainJourney> createJourney({
    required String clientRequestId,
    required String regionKey,
    required List<String> questKeys,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) => throw UnimplementedError();

  @override
  Future<DomainJourney> replaceJourneyQuests({
    required String journeyId,
    required List<String> questKeys,
  }) => throw UnimplementedError();

  @override
  Future<String> uploadPhoto(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) => throw UnimplementedError();

  @override
  Future<QuestVerification> verifyQuest({
    required String questKey,
    String? journeyId,
    String? photoUrl,
    String? answer,
    String? qrPayload,
  }) => throw UnimplementedError();
}

Future<ProviderContainer> _container(_AuthRepository auth) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      tripDnaRepositoryProvider.overrideWithValue(_TripDnaRepository(auth)),
      mapRepositoryProvider.overrideWithValue(_MapRepository()),
      domainRepositoryProvider.overrideWithValue(_DomainRepository()),
      onboardingTourProvider.overrideWith(
        () => OnboardingTourNotifier(
          const OnboardingTourState(step: 4, skipped: true),
        ),
      ),
    ],
  );
  await container.read(authControllerProvider.notifier).bootstrap();
  return container;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login onboarding DNA home and logout form one auth flow', (
    tester,
  ) async {
    final auth = _AuthRepository();
    final container = await _container(auth);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ColorTripApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('회원가입'), findsOneWidget);

    await tester.tap(find.text('[필수] 이용약관 동의'));
    await tester.tap(find.text('[필수] 개인정보 처리방침'));
    await tester.pump();
    await tester.ensureVisible(find.text('다음'));
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.textContaining('어떤 여행을 좋아하나요?'), findsOneWidget);

    await tester.tap(find.text('액티비티를 즐겨요'));
    await tester.tap(find.text('결과 보기'));
    await tester.pumpAndSettle();
    expect(find.text('에너지 탐험가'), findsOneWidget);

    await tester.tap(find.text('홈으로'));
    await tester.pumpAndSettle();
    expect(find.text('홈'), findsWidgets);

    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('카카오로 시작하기'), findsOneWidget);
  });

  testWidgets('a completed server session restores directly to home', (
    tester,
  ) async {
    final auth = _AuthRepository()..user = _profile(OnboardingStep.complete);
    final container = await _container(auth);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ColorTripApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('홈'), findsWidgets);
    expect(find.text('카카오로 시작하기'), findsNothing);
  });
}
