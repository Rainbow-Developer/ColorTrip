/// KAN-28 기능 검증 — 홈 추천 배너 · 여행 시작 이름/날짜 입력 시트 · 여행 목록 표시.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:colortrip/core/config/app_config.dart';
import 'package:colortrip/core/network/dio_client.dart';
import 'package:colortrip/data/repositories/domain_repository.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:colortrip/app/app_shell.dart';
import 'package:colortrip/core/constants.dart';
import 'package:colortrip/core/widgets/chungbuk_map.dart';
import 'package:colortrip/core/widgets/coach_mark.dart';
import 'package:colortrip/data/models/auth_models.dart';
import 'package:colortrip/data/models/quest.dart';
import 'package:colortrip/data/static/quests_data.dart';
import 'package:colortrip/features/home/home_screen.dart';
import 'package:colortrip/features/profile/profile_screen.dart';
import 'package:colortrip/features/quests/region_overview_screen.dart';
import 'package:colortrip/features/quests/region_quest_select_screen.dart';
import 'package:colortrip/features/travel/journey_detail_screen.dart';
import 'package:colortrip/features/travel/travel_list_screen.dart';
import 'package:colortrip/state/auth_controller.dart';
import 'package:colortrip/state/onboarding_tour_notifier.dart';
import 'package:colortrip/state/progress_notifier.dart';
import 'package:colortrip/state/progress_state.dart';
import 'package:colortrip/state/repository_providers.dart';

/// 온보딩 투어는 main.dart에서 초기값을 주입해야 하는 프로바이더라 테스트에서도 주입한다.
/// 코치마크가 화면을 덮지 않도록 "완료" 상태로 둔다.
final _tourDoneOverride = onboardingTourProvider.overrideWith(
  () => OnboardingTourNotifier(
    const OnboardingTourState(step: kOnboardingTotalSteps, skipped: true),
  ),
);

final _testConfig = AppConfig.fromValues(
  kakaoNativeAppKey: 'test-native-key',
  apiBaseUrl: 'https://api.example.com/api/v1',
);

ScrollableState _firstPageScrollable(WidgetTester tester) {
  return tester.state<ScrollableState>(
    find.descendant(
      of: find.byType(SingleChildScrollView).first,
      matching: find.byType(Scrollable),
    ),
  );
}

class _DelayedHeightBox extends StatefulWidget {
  const _DelayedHeightBox({
    required this.initialHeight,
    required this.expandedHeight,
    required this.delay,
  });

  final double initialHeight;
  final double expandedHeight;
  final Duration delay;

  @override
  State<_DelayedHeightBox> createState() => _DelayedHeightBoxState();
}

class _DelayedHeightBoxState extends State<_DelayedHeightBox> {
  Timer? _timer;
  late double _height = widget.initialHeight;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _height = widget.expandedHeight);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(height: _height);
}

class _DomainRepository implements DomainRepository {
  DomainSnapshot snapshot = const DomainSnapshot(
    catalog: DomainCatalog(
      regionIdsByKey: {'danyang': 'region-uuid'},
      regionKeysById: {'region-uuid': 'danyang'},
      questIdsByKey: {'dy1': 'quest-uuid'},
      questKeysById: {'quest-uuid': 'dy1'},
    ),
    journeys: [],
    completedQuestKeys: {},
    regionProgress: {},
    regionTripCount: {},
    timeline: [],
  );

  @override
  Future<DomainSnapshot> fetchSnapshot() async => snapshot;

  @override
  Future<List<DomainRecommendedRegion>>
  fetchUnvisitedRecommendedRegions() async => const [
    DomainRecommendedRegion(
      regionKey: 'danyang',
      matchingQuestCount: 3,
      availableQuestCount: 20,
    ),
  ];

  @override
  Future<List<String>> fetchRecommendedQuestKeys({
    String? category,
    required String regionKey,
    int size = 3,
  }) async => const ['dy4', 'dy3', 'dy2'];

  @override
  Future<DomainJourney> createJourney({
    required String clientRequestId,
    required String regionKey,
    required List<String> questKeys,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final journey = DomainJourney(
      id: 'journey-uuid',
      regionKey: regionKey,
      questKeys: questKeys,
      title: title,
      startDate: startDate,
      endDate: endDate,
      status: 'in_progress',
      createdAt: DateTime.now(),
    );
    snapshot = DomainSnapshot(
      catalog: snapshot.catalog,
      journeys: [journey],
      completedQuestKeys: const {},
      regionProgress: const {},
      regionTripCount: const {},
      timeline: const [],
    );
    return journey;
  }

  @override
  Future<DomainJourney> replaceJourneyQuests({
    required String journeyId,
    required List<String> questKeys,
  }) => throw UnimplementedError();

  @override
  Future<DomainJourney> updateJourney({
    required String journeyId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteJourney({required String journeyId}) =>
      throw UnimplementedError();

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

class _DelayedRecommendationRepository extends _DomainRepository {
  final unvisitedCompleter = Completer<List<DomainRecommendedRegion>>();
  final questsCompleter = Completer<List<String>>();

  @override
  Future<List<DomainRecommendedRegion>> fetchUnvisitedRecommendedRegions() =>
      unvisitedCompleter.future;

  @override
  Future<List<String>> fetchRecommendedQuestKeys({
    String? category,
    required String regionKey,
    int size = 3,
  }) => questsCompleter.future;
}

Widget _wrap(
  Widget child, {
  List<GoRoute> extraRoutes = const [],
  ProviderContainer? container,
}) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, _) => child),
      ...extraRoutes,
    ],
  );
  final app = MaterialApp.router(
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: router,
  );
  if (container != null) {
    return UncontrolledProviderScope(container: container, child: app);
  }
  return ProviderScope(overrides: [_tourDoneOverride], child: app);
}

void main() {
  test('퀘스트 정적 데이터는 11개 시·군 각 20개씩 220개다', () {
    expect(kQuests.length, 220);
    final byRegion = <String, int>{};
    for (final q in kQuests) {
      byRegion[q.region] = (byRegion[q.region] ?? 0) + 1;
    }
    expect(byRegion.length, 11);
    expect(byRegion.values.every((c) => c == 20), isTrue);
    // id는 전역 유일해야 한다(TourAPI 생성분 포함).
    expect(kQuests.map((q) => q.id).toSet().length, kQuests.length);
    // OX퀴즈 퀘스트는 질문·정답이 반드시 있어야 한다.
    for (final q in kQuests.where((q) => q.verify == 'quiz')) {
      expect(q.quizQuestion, isNotNull, reason: q.id);
      expect(q.quizAnswer, isNotNull, reason: q.id);
    }
  });

  testWidgets('홈에 서버 추천 여행지 배너가 뜬다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        _tourDoneOverride,
        domainRepositoryProvider.overrideWithValue(_DomainRepository()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_wrap(const HomeScreen(), container: container));
    await tester.pumpAndSettle();

    expect(find.textContaining('추천 여행지'), findsOneWidget);
    expect(find.text('단양군'), findsWidgets);
    expect(find.text('자연탐험 퀘스트 3개가 기다리고 있어요'), findsOneWidget);

    // 서버가 반환한 순서와 퀘스트를 그대로 카드에 표시한다.
    Quest questById(String id) => kQuests.firstWhere((quest) => quest.id == id);
    expect(find.text(questById('dy4').title), findsWidgets);
    expect(find.text(questById('dy3').title), findsWidgets);
    expect(find.text(questById('dy2').title), findsWidgets);
  });

  testWidgets('지도 튜토리얼 중에는 뒤 화면이 스크롤되지 않는다', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        onboardingTourProvider.overrideWith(
          () => OnboardingTourNotifier(
            const OnboardingTourState(step: 0, skipped: false),
          ),
        ),
        domainRepositoryProvider.overrideWithValue(_DomainRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(const HomeScreen(), container: container));
    await tester.pumpAndSettle();

    final scrollable = _firstPageScrollable(tester);
    final before = scrollable.position.pixels;

    await tester.drag(find.byType(ChungbukMap), const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, before);

    final mapRect = tester.getRect(find.byType(ChungbukMap));
    final messageCardRect = tester.getRect(
      find.byKey(const ValueKey('coach-mark-message-card')),
    );
    expect(mapRect.top, greaterThan(80));
    expect(messageCardRect.top, greaterThanOrEqualTo(mapRect.bottom));
    expect(messageCardRect.bottom, lessThanOrEqualTo(800));

    await tester.dragFrom(const Offset(4, 400), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(find.text('지도에서 지역을 눌러보세요'), findsOneWidget);
    expect(scrollable.position.pixels, before);

    tester.binding.handlePointerEvent(
      const PointerDownEvent(pointer: 7, position: Offset(4, 400)),
    );
    tester.binding.handlePointerEvent(
      const PointerUpEvent(
        pointer: 7,
        position: Offset(4, 400 + kTouchSlop + 1),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('지도에서 지역을 눌러보세요'), findsOneWidget);

    await tester.tapAt(const Offset(4, 400));
    await tester.pumpAndSettle();

    expect(find.text('지도에서 지역을 눌러보세요'), findsNothing);
    expect(container.read(onboardingTourProvider).step, 0);
    expect(container.read(onboardingTourProvider).skipped, isFalse);
    expect(scrollable.position.pixels, 0);
    expect(find.textContaining('추천 여행지'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(0));

    await container.read(onboardingTourProvider.notifier).skipForever();
    await tester.pumpAndSettle();
    await container.read(onboardingTourProvider.notifier).restart();
    await tester.pumpAndSettle();

    expect(find.text('지도에서 지역을 눌러보세요'), findsOneWidget);
    final restartedMapRect = tester.getRect(find.byType(ChungbukMap));
    final restartedMessageCardRect = tester.getRect(
      find.byKey(const ValueKey('coach-mark-message-card')),
    );
    expect(restartedMapRect.top, greaterThan(80));
    expect(
      restartedMessageCardRect.top,
      greaterThanOrEqualTo(restartedMapRect.bottom),
    );
    expect(restartedMessageCardRect.bottom, lessThanOrEqualTo(800));
  });

  testWidgets('작은 화면에서도 지도 코치마크 말풍선은 화면 안에 배치된다', (tester) async {
    tester.view.physicalSize = const Size(400, 620);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        onboardingTourProvider.overrideWith(
          () => OnboardingTourNotifier(
            const OnboardingTourState(step: 0, skipped: false),
          ),
        ),
        domainRepositoryProvider.overrideWithValue(_DomainRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(const HomeScreen(), container: container));
    await tester.pumpAndSettle();

    final scrollable = _firstPageScrollable(tester);
    expect(scrollable.position.pixels, greaterThanOrEqualTo(0));

    final mapRect = tester.getRect(find.byType(ChungbukMap));
    final messageCardRect = tester.getRect(
      find.byKey(const ValueKey('coach-mark-message-card')),
    );
    expect(mapRect.top, greaterThan(40));
    expect(messageCardRect.top, greaterThanOrEqualTo(mapRect.bottom));
    expect(messageCardRect.bottom, lessThanOrEqualTo(620));

    await tester.tapAt(const Offset(4, 310));
    await tester.pumpAndSettle();

    expect(find.text('지도에서 지역을 눌러보세요'), findsNothing);
    expect(scrollable.position.pixels, 0);
  });

  testWidgets('큰 화면의 지도 코치마크는 홈 상단 레이아웃을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        onboardingTourProvider.overrideWith(
          () => OnboardingTourNotifier(
            const OnboardingTourState(step: 0, skipped: false),
          ),
        ),
        domainRepositoryProvider.overrideWithValue(_DomainRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(const HomeScreen(), container: container));
    await tester.pumpAndSettle();

    final scrollable = _firstPageScrollable(tester);
    expect(scrollable.position.pixels, greaterThanOrEqualTo(0));
    expect(find.textContaining('추천 여행지'), findsOneWidget);

    final mapRect = tester.getRect(find.byType(ChungbukMap));
    final messageCardRect = tester.getRect(
      find.byKey(const ValueKey('coach-mark-message-card')),
    );
    expect(mapRect.top, greaterThan(300));
    expect(messageCardRect.top, greaterThanOrEqualTo(mapRect.bottom));
    expect(messageCardRect.bottom, lessThanOrEqualTo(900));
  });

  testWidgets('홈 시작 지도 코치마크는 추천 배너 레이아웃이 준비된 뒤 표시된다', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final repository = _DelayedRecommendationRepository();
    final container = ProviderContainer(
      overrides: [
        onboardingTourProvider.overrideWith(
          () => OnboardingTourNotifier(
            const OnboardingTourState(step: 0, skipped: false),
          ),
        ),
        domainRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(const HomeScreen(), container: container));
    await tester.pump();

    expect(find.text('지도에서 지역을 눌러보세요'), findsNothing);

    repository.unvisitedCompleter.complete(const [
      DomainRecommendedRegion(
        regionKey: 'danyang',
        matchingQuestCount: 3,
        availableQuestCount: 20,
      ),
    ]);
    await tester.pump();
    await tester.pump();

    expect(find.text('지도에서 지역을 눌러보세요'), findsNothing);

    repository.questsCompleter.complete(const ['dy4', 'dy3', 'dy2']);
    await tester.pumpAndSettle();

    expect(find.text('지도에서 지역을 눌러보세요'), findsOneWidget);
    final mapRect = tester.getRect(find.byType(ChungbukMap));
    final messageCardRect = tester.getRect(
      find.byKey(const ValueKey('coach-mark-message-card')),
    );
    expect(mapRect.top, greaterThan(300));
    expect(messageCardRect.top, greaterThanOrEqualTo(mapRect.bottom));
    expect(messageCardRect.bottom, lessThanOrEqualTo(900));
  });

  testWidgets('지도에서 지역을 눌렀다가 뒤로 오면 홈 지도 코치마크가 다시 보인다', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        onboardingTourProvider.overrideWith(
          () => OnboardingTourNotifier(
            const OnboardingTourState(step: 0, skipped: false),
          ),
        ),
        domainRepositoryProvider.overrideWithValue(_DomainRepository()),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/region/:id',
          builder: (_, state) => Scaffold(
            appBar: AppBar(),
            body: Text('지역 화면 ${state.pathParameters['id']}'),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/travel',
                  builder: (_, _) => const TravelListScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/timeline', builder: (_, _) => const Scaffold(body: Text('Timeline'))),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/my', builder: (_, _) => const ProfileScreen()),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: const Locale('ko'),
          supportedLocales: const [Locale('ko')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('지도에서 지역을 눌러보세요'), findsOneWidget);

    final mapRect = tester.getRect(find.byType(ChungbukMap));
    final danyangTap = mapRect.topLeft.translate(
      (400 - 10) / 480 * mapRect.width,
      (100 - 10) / 460 * mapRect.height,
    );
    await tester.tapAt(danyangTap);
    await tester.pumpAndSettle();

    expect(find.textContaining('지역 화면'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('지도에서 지역을 눌러보세요'), findsOneWidget);
    final returnedMapRect = tester.getRect(find.byType(ChungbukMap));
    final returnedMessageCardRect = tester.getRect(
      find.byKey(const ValueKey('coach-mark-message-card')),
    );
    expect(
      returnedMessageCardRect.top,
      greaterThanOrEqualTo(returnedMapRect.bottom),
    );
    expect(returnedMessageCardRect.bottom, lessThanOrEqualTo(900));
  });

  testWidgets('마이에서 튜토리얼을 다시 켜면 홈 지도 코치마크가 정렬된다', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    const user = UserProfile(
      id: 'user-id',
      nickname: '컬러트립',
      birthDate: null,
      profileImage: null,
      dna: 'nature',
      socialProvider: 'kakao',
      onboardingStep: OnboardingStep.complete,
      isRestored: false,
    );
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(_testConfig),
        onboardingTourProvider.overrideWith(
          () => OnboardingTourNotifier(
            const OnboardingTourState(
              step: kOnboardingTotalSteps,
              skipped: true,
            ),
          ),
        ),
        currentUserProvider.overrideWithValue(user),
        domainRepositoryProvider.overrideWithValue(_DomainRepository()),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/travel',
                  builder: (_, _) => const TravelListScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/timeline', builder: (_, _) => const Scaffold(body: Text('Timeline'))),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/my', builder: (_, _) => const ProfileScreen()),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: const Locale('ko'),
          supportedLocales: const [Locale('ko')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    await tester.tap(find.text('이용 가이드 다시 보기'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('지도에서 지역을 눌러보세요'), findsOneWidget);

    final mapRect = tester.getRect(find.byType(ChungbukMap));
    final messageCardRect = tester.getRect(
      find.byKey(const ValueKey('coach-mark-message-card')),
    );
    expect(mapRect.top, greaterThan(80));
    expect(messageCardRect.top, greaterThanOrEqualTo(mapRect.bottom));
    expect(messageCardRect.bottom, lessThanOrEqualTo(800));
    expect(_firstPageScrollable(tester).position.pixels, greaterThan(0));

    await tester.tapAt(const Offset(4, 400));
    await tester.pumpAndSettle();

    expect(find.text('지도에서 지역을 눌러보세요'), findsNothing);
    expect(_firstPageScrollable(tester).position.pixels, 0);

    await tester.tap(find.byIcon(Icons.person_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();

    expect(find.text('지도에서 지역을 눌러보세요'), findsOneWidget);
  });

  testWidgets('가이드가 켜져 있으면 완료 단계 이후에도 약속된 화면에서 다시 보인다', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final domainRepository = _DomainRepository()
      ..snapshot = DomainSnapshot(
        catalog: const DomainCatalog(
          regionIdsByKey: {'danyang': 'region-uuid'},
          regionKeysById: {'region-uuid': 'danyang'},
          questIdsByKey: {'dy1': 'quest-uuid'},
          questKeysById: {'quest-uuid': 'dy1'},
        ),
        journeys: [
          DomainJourney(
            id: 'journey-uuid',
            regionKey: 'danyang',
            questKeys: const ['dy1'],
            title: '단양 여행',
            startDate: DateTime(2026, 8, 21),
            endDate: DateTime(2026, 8, 22),
            status: 'in_progress',
            createdAt: DateTime(2026, 8, 21),
          ),
        ],
        completedQuestKeys: const {},
        regionProgress: const {},
        regionTripCount: const {},
        timeline: const [],
      );
    final container = ProviderContainer(
      overrides: [
        onboardingTourProvider.overrideWith(
          () => OnboardingTourNotifier(
            const OnboardingTourState(
              step: kOnboardingTotalSteps,
              skipped: false,
            ),
          ),
        ),
        domainRepositoryProvider.overrideWithValue(domainRepository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrap(const HomeScreen(), container: container));
    await tester.pumpAndSettle();

    expect(find.text('지도에서 지역을 눌러보세요'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        const JourneyDetailScreen(journeyId: 'journey-uuid'),
        container: container,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('퀘스트를 인증해보세요'), findsOneWidget);
  });

  testWidgets('코치마크는 부모 스크롤 한계에서도 말풍선 높이를 제한한다', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final targetKey = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingTourProvider.overrideWith(
            () => OnboardingTourNotifier(
              const OnboardingTourState(step: 0, skipped: false),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                SingleChildScrollView(
                  child: SizedBox(
                    height: 320,
                    child: Column(
                      children: [
                        const SizedBox(height: 170),
                        SizedBox(
                          key: targetKey,
                          width: 300,
                          height: 50,
                          child: const ColoredBox(color: AppColors.mapEmpty),
                        ),
                      ],
                    ),
                  ),
                ),
                CoachMarkOverlay(
                  targetKey: targetKey,
                  stepIndex: 0,
                  title: '지도에서 지역을 눌러보세요',
                  body:
                      '가고 싶은 지역을 누르면 추천 퀘스트를 볼 수 있어요. '
                      '작은 화면에서는 설명이 카드 안에서 스크롤돼야 해요.',
                  forceBubbleBelow: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = _firstPageScrollable(tester);
    expect(scrollable.position.maxScrollExtent, 0);

    final messageCardRect = tester.getRect(
      find.byKey(const ValueKey('coach-mark-message-card')),
    );
    expect(messageCardRect.bottom, lessThanOrEqualTo(360));
    expect(messageCardRect.height, lessThan(140));
  });

  testWidgets('지도에서 지역을 누른 개요 화면은 사용자 프로필 DNA를 우선 표시한다', (tester) async {
    const user = UserProfile(
      id: 'user-id',
      nickname: '컬러트립',
      birthDate: null,
      profileImage: null,
      dna: 'food',
      socialProvider: 'kakao',
      onboardingStep: OnboardingStep.complete,
      isRestored: false,
    );
    final container = ProviderContainer(
      overrides: [
        _tourDoneOverride,
        currentUserProvider.overrideWithValue(user),
        domainRepositoryProvider.overrideWithValue(_DomainRepository()),
      ],
    );
    addTearDown(container.dispose);
    container.read(progressProvider.notifier).setDnaType('nature');

    await tester.pumpWidget(
      _wrap(
        const RegionOverviewScreen(regionId: 'danyang'),
        container: container,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('로컬 미식가'), findsOneWidget);
    expect(find.text('자연탐험형 여행자'), findsNothing);
    final expectedBackground = questTypeIconColors['food']!.background;
    final hasMatchingBackground = tester
        .widgetList<Container>(find.byType(Container))
        .any((container) {
          final decoration = container.decoration;
          if (decoration is! BoxDecoration) return false;
          return decoration.color == expectedBackground;
        });
    expect(hasMatchingBackground, isTrue);
  });

  testWidgets('지역 개요 화면은 legacy active 사용자 DNA를 activity로 보정한다', (
    tester,
  ) async {
    const user = UserProfile(
      id: 'user-id',
      nickname: '컬러트립',
      birthDate: null,
      profileImage: null,
      dna: 'active',
      socialProvider: 'kakao',
      onboardingStep: OnboardingStep.complete,
      isRestored: false,
    );
    final container = ProviderContainer(
      overrides: [
        _tourDoneOverride,
        currentUserProvider.overrideWithValue(user),
        domainRepositoryProvider.overrideWithValue(_DomainRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrap(
        const RegionOverviewScreen(regionId: 'danyang'),
        container: container,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('에너지 탐험가'), findsOneWidget);
    expect(find.text('자연탐험형 여행자'), findsNothing);
  });

  testWidgets('여행 시작하기 시 이름·날짜 입력 시트를 거쳐 여행이 등록된다', (tester) async {
    // 전체 화면 날짜 피커의 날짜 셀이 기본 서피스(800x600) 밖으로 밀려나 탭이 닿지 않는다.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        _tourDoneOverride,
        domainRepositoryProvider.overrideWithValue(_DomainRepository()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _wrap(
        const RegionQuestSelectScreen(regionId: 'danyang'),
        container: container,
        extraRoutes: [
          GoRoute(path: '/travel', builder: (_, _) => const TravelListScreen()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // 퀘스트 1개 선택 → 여행 시작하기 → 시트 표시.
    await tester.tap(find.text('소백산 연화봉 전망대 인증'));
    await tester.pump();
    await tester.tap(find.text('여행 시작하기 (1)'));
    await tester.pumpAndSettle();
    expect(find.text('여행 정보를 입력해주세요'), findsOneWidget);

    // 이름 기본값은 "단양 여행", 날짜를 고르기 전엔 시작 버튼 비활성.
    expect(find.text('단양 여행'), findsOneWidget);
    final startButton = find.widgetWithText(ElevatedButton, '여행 시작하기');
    expect(tester.widget<ElevatedButton>(startButton).enabled, isFalse);

    // 이름 수정 후 날짜 범위 선택(피커에서 오늘 날짜를 시작·종료일로 두 번 탭).
    await tester.enterText(find.byType(TextField).last, '단양 힐링 여행');
    await tester.tap(find.text('시작일 ~ 종료일 선택'));
    await tester.pumpAndSettle();
    // 달력 리스트의 첫 달(이번 달)에서 오늘 날짜를 시작·종료일로 두 번 탭.
    final today = DateTime.now().day.toString();
    await tester.tap(find.text(today).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(today).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택 완료'));
    await tester.pumpAndSettle();

    // 시작 → 상태에 이름·기간이 저장되고 여행 목록으로 이동, 카드에 표시된다.
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    final state = container.read(progressProvider);
    final info = state.tripInfoOf('danyang');
    expect(info, isNotNull);
    expect(info!.name, '단양 힐링 여행');
    expect(state.tripQuestsOf('danyang'), {'dy1'});

    expect(find.text('단양 힐링 여행'), findsOneWidget);
    expect(find.text(info.periodLabel), findsOneWidget);
    expect(find.text('진행중인 여행'), findsOneWidget);
  });

  testWidgets('튜토리얼 코치마크는 배경을 막고 하이라이트된 버튼만 통과시킨다', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final tourStepTwoOverride = onboardingTourProvider.overrideWith(
      () => OnboardingTourNotifier(
        const OnboardingTourState(step: 2, skipped: false),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        tourStepTwoOverride,
        domainRepositoryProvider.overrideWithValue(_DomainRepository()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _wrap(
        const RegionQuestSelectScreen(regionId: 'danyang'),
        container: container,
        extraRoutes: [
          GoRoute(path: '/travel', builder: (_, _) => const SizedBox.shrink()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('여행을 시작해보세요'), findsNothing);

    await tester.tap(find.text('소백산 연화봉 전망대 인증'));
    await tester.pumpAndSettle();

    expect(find.text('여행을 시작해보세요'), findsOneWidget);
    expect(find.text('여행 시작하기 (1)'), findsOneWidget);

    final paintedScrim = find.byKey(const ValueKey('coach-mark-scrim'));
    expect(paintedScrim, findsOneWidget);
    final scrimSize = tester.getSize(paintedScrim);
    expect(
      scrimSize.width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );
    expect(scrimSize.height, greaterThan(1000));

    await tester.tap(find.text('도담삼봉에서 인생샷 남기기'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('여행 시작하기 (1)'), findsOneWidget);
    expect(find.text('여행 시작하기 (2)'), findsNothing);
    expect(find.text('여행을 시작해보세요'), findsNothing);

    await tester.tap(find.text('도담삼봉에서 인생샷 남기기'));
    await tester.pumpAndSettle();

    expect(find.text('여행 시작하기 (2)'), findsOneWidget);

    await tester.tap(find.text('여행 시작하기 (2)'));
    await tester.pumpAndSettle();

    expect(find.text('여행 정보를 입력해주세요'), findsOneWidget);
    expect(container.read(onboardingTourProvider).step, 2);

    Navigator.of(tester.element(find.text('여행 정보를 입력해주세요'))).pop();
    await tester.pumpAndSettle();
    expect(container.read(onboardingTourProvider).step, 2);

    await tester.tap(find.text('여행 시작하기 (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작일 ~ 종료일 선택'));
    await tester.pumpAndSettle();

    final today = DateTime.now().day.toString();
    await tester.tap(find.text(today).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(today).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '여행 시작하기'));
    await tester.pumpAndSettle();

    expect(container.read(onboardingTourProvider).step, 3);
  });

  testWidgets('비동기 레이아웃 변경 후 코치마크가 이동한 타겟을 다시 측정한다', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final targetKey = GlobalKey();
    var targetTop = 120.0;
    var tapCount = 0;
    late StateSetter rebuild;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingTourProvider.overrideWith(
            () => OnboardingTourNotifier(
              const OnboardingTourState(step: 2, skipped: false),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Stack(
                  children: [
                    Positioned(
                      top: targetTop,
                      left: 100,
                      width: 240,
                      child: ElevatedButton(
                        key: targetKey,
                        onPressed: () => tapCount++,
                        child: const Text('움직이는 타겟'),
                      ),
                    ),
                    CoachMarkOverlay(
                      targetKey: targetKey,
                      stepIndex: 2,
                      title: '이동 테스트',
                      body: '레이아웃 변경 후 새 위치를 사용합니다.',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    rebuild(() => targetTop = 620);
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(220, 148));
    await tester.pump();
    expect(tapCount, 0);

    await tester.tap(find.text('움직이는 타겟'));
    await tester.pump();
    expect(tapCount, 1);
  });

  testWidgets('부모 재빌드 없이 위쪽 레이아웃이 커져도 코치마크가 타겟을 다시 측정한다', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final targetKey = GlobalKey();
    var tapCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingTourProvider.overrideWith(
            () => OnboardingTourNotifier(
              const OnboardingTourState(step: 0, skipped: false),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Column(
                  children: [
                    const _DelayedHeightBox(
                      initialHeight: 80,
                      expandedHeight: 420,
                      delay: Duration(milliseconds: 80),
                    ),
                    ElevatedButton(
                      key: targetKey,
                      onPressed: () => tapCount++,
                      child: const Text('비동기 타겟'),
                    ),
                  ],
                ),
                CoachMarkOverlay(
                  targetKey: targetKey,
                  stepIndex: 0,
                  title: '지도에서 지역을 눌러보세요',
                  body: '위쪽 배너가 늦게 커져도 새 위치를 사용합니다.',
                  scrollToTarget: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final targetRect = tester.getRect(find.byKey(targetKey));
    expect(targetRect.top, greaterThan(400));

    await tester.tapAt(const Offset(120, 100));
    await tester.pump();
    expect(tapCount, 0);

    await tester.tapAt(targetRect.center);
    await tester.pump();
    expect(tapCount, 1);
  });

  testWidgets('화면 크기가 바뀌면 코치마크가 타겟 좌표를 다시 측정한다', (tester) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final targetKey = GlobalKey();
    var targetTapCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingTourProvider.overrideWith(
            () => OnboardingTourNotifier(
              const OnboardingTourState(step: 0, skipped: false),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 100,
                  right: 100,
                  bottom: 120,
                  height: 50,
                  child: GestureDetector(
                    key: targetKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: () => targetTapCount++,
                    child: const ColoredBox(color: AppColors.mapEmpty),
                  ),
                ),
                CoachMarkOverlay(
                  targetKey: targetKey,
                  stepIndex: 0,
                  title: '지도에서 지역을 눌러보세요',
                  body: '가고 싶은 지역을 누르면 추천 퀘스트를 볼 수 있어요.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(800, 500);
    await tester.pumpAndSettle();

    final targetRect = tester.getRect(find.byKey(targetKey));
    final messageCardRect = tester.getRect(
      find.byKey(const ValueKey('coach-mark-message-card')),
    );
    expect(targetRect.bottom, lessThan(500));
    expect(messageCardRect.bottom, lessThanOrEqualTo(500));

    await tester.tapAt(targetRect.center);
    await tester.pump();

    expect(targetTapCount, 1);
  });

  testWidgets('텍스트 크기와 키보드 인셋이 바뀌면 코치마크를 다시 측정한다', (tester) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final targetKey = GlobalKey();
    var textScale = 1.0;
    var bottomInset = 0.0;
    var targetTapCount = 0;
    late StateSetter rebuild;

    final fixedCoachMarkStack = Stack(
      children: [
        Builder(
          builder: (context) {
            final insets = MediaQuery.viewInsetsOf(context);
            return Positioned(
              left: 100,
              right: 100,
              bottom: 80 + insets.bottom,
              height: 50,
              child: GestureDetector(
                key: targetKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => targetTapCount++,
                child: const ColoredBox(color: AppColors.mapEmpty),
              ),
            );
          },
        ),
        CoachMarkOverlay(
          targetKey: targetKey,
          stepIndex: 0,
          title: '지도에서 지역을 눌러보세요',
          body:
              '가고 싶은 지역을 누르면 추천 퀘스트를 볼 수 있어요. '
              '텍스트 크기와 키보드 영역이 바뀌어도 위치가 맞아야 해요.',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingTourProvider.overrideWith(
            () => OnboardingTourNotifier(
              const OnboardingTourState(step: 0, skipped: false),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                final media = MediaQuery.of(context);
                return MediaQuery(
                  data: media.copyWith(
                    textScaler: TextScaler.linear(textScale),
                    viewInsets: EdgeInsets.only(bottom: bottomInset),
                  ),
                  child: fixedCoachMarkStack,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initialCardHeight = tester
        .getRect(find.byKey(const ValueKey('coach-mark-message-card')))
        .height;

    rebuild(() {
      textScale = 1.7;
      bottomInset = 180;
    });
    await tester.pumpAndSettle();

    final targetRect = tester.getRect(find.byKey(targetKey));
    final messageCardRect = tester.getRect(
      find.byKey(const ValueKey('coach-mark-message-card')),
    );
    expect(targetRect.top, lessThan(600));
    expect(messageCardRect.height, greaterThan(initialCardHeight));
    expect(messageCardRect.bottom, lessThanOrEqualTo(800));

    await tester.tapAt(targetRect.center);
    await tester.pump();

    expect(targetTapCount, 1);
  });

  test('기간 표기는 같은 해면 연도를 한 번만 쓴다', () {
    expect(
      TripInfo.formatPeriod(DateTime(2026, 7, 20), DateTime(2026, 7, 22)),
      '2026.07.20 ~ 07.22',
    );
    expect(
      TripInfo.formatPeriod(DateTime(2026, 12, 30), DateTime(2027, 1, 2)),
      '2026.12.30 ~ 2027.01.02',
    );
  });
}
