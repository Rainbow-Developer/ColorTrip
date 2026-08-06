/// KAN-28 기능 검증 — 홈 추천 배너 · 여행 시작 이름/날짜 입력 시트 · 여행 목록 표시.
library;

import 'dart:typed_data';

import 'package:colortrip/data/repositories/domain_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:colortrip/data/models/quest.dart';
import 'package:colortrip/data/static/quests_data.dart';
import 'package:colortrip/features/home/home_screen.dart';
import 'package:colortrip/features/quests/region_quest_select_screen.dart';
import 'package:colortrip/features/travel/travel_list_screen.dart';
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
  Future<String> uploadPhoto(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) => throw UnimplementedError();

  @override
  Future<QuestVerification> verifyQuest({
    required String questKey,
    String? journeyId,
    double? latitude,
    double? longitude,
    String? photoUrl,
    String? answer,
    String? qrPayload,
  }) => throw UnimplementedError();
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
    await tester.tap(find.text('선택'));
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
