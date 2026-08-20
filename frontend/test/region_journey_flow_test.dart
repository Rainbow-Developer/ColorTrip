/// KAN-99 — 지역 탐색과 여행 상세 진입 흐름 회귀 검증.
library;

import 'dart:typed_data';

import 'package:colortrip/data/repositories/domain_repository.dart';
import 'package:colortrip/features/quests/region_overview_screen.dart';
import 'package:colortrip/features/quests/region_quest_select_screen.dart';
import 'package:colortrip/features/travel/journey_detail_screen.dart';
import 'package:colortrip/state/onboarding_tour_notifier.dart';
import 'package:colortrip/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _tourDoneOverride = onboardingTourProvider.overrideWith(
  () => OnboardingTourNotifier(
    const OnboardingTourState(step: kOnboardingTotalSteps, skipped: true),
  ),
);

class _FakeDomainRepository implements DomainRepository {
  _FakeDomainRepository(this.snapshot);

  DomainSnapshot snapshot;
  String? replacedJourneyId;

  @override
  Future<DomainSnapshot> fetchSnapshot() async => snapshot;

  @override
  Future<List<String>> fetchRecommendedQuestKeys({String? category, 
    required String regionKey,
    int size = 3,
  }) async => const ['dy4', 'dy3', 'dy2'];

  @override
  Future<List<DomainRecommendedRegion>>
  fetchUnvisitedRecommendedRegions() async => const [];

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
  }) async {
    replacedJourneyId = journeyId;
    return snapshot.journeys.firstWhere((journey) => journey.id == journeyId);
  }

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

DomainSnapshot _snapshot({
  List<DomainJourney> journeys = const [],
  Set<String> completedQuestKeys = const {},
}) {
  return DomainSnapshot(
    catalog: const DomainCatalog(
      regionIdsByKey: {
        'danyang': 'region-danyang',
        'cheongju': 'region-cheongju',
      },
      regionKeysById: {
        'region-danyang': 'danyang',
        'region-cheongju': 'cheongju',
      },
      questIdsByKey: {
        'dy1': 'quest-dy1',
        'dy2': 'quest-dy2',
        'dy3': 'quest-dy3',
        'dy4': 'quest-dy4',
      },
      questKeysById: {
        'quest-dy1': 'dy1',
        'quest-dy2': 'dy2',
        'quest-dy3': 'dy3',
        'quest-dy4': 'dy4',
      },
    ),
    journeys: journeys,
    completedQuestKeys: completedQuestKeys,
    regionProgress: const {},
    regionTripCount: const {},
    timeline: [
      for (final key in completedQuestKeys)
        DomainTimelineEntry(
          questKey: key,
          occurredAt: DateTime(2026, 8, 19),
          photoUrl: null,
        ),
    ],
  );
}

DomainJourney _journey({
  required String id,
  required String regionKey,
  required String title,
  required String status,
  required DateTime createdAt,
}) {
  return DomainJourney(
    id: id,
    regionKey: regionKey,
    questKeys: const ['dy1'],
    title: title,
    startDate: DateTime(2026, 8, 19),
    endDate: DateTime(2026, 8, 20),
    status: status,
    createdAt: createdAt,
  );
}

Widget _app({
  required DomainRepository repository,
  required Widget home,
  List<GoRoute> routes = const [],
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      ...routes,
    ],
  );
  return ProviderScope(
    overrides: [
      _tourDoneOverride,
      domainRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('지역 화면은 축약 DNA와 스냅형 추천 캐러셀을 항상 표시한다', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = _FakeDomainRepository(_snapshot());
    await tester.pumpWidget(
      _app(
        repository: repository,
        home: const RegionOverviewScreen(regionId: 'danyang'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('자연탐험형 여행자'), findsOneWidget);
    expect(find.text('자연친화'), findsNothing);
    final description = tester.widget<Text>(
      find.text('대자연 속에서 에너지를 얻고 조용한 힐링을 즐기는 탐험가예요.'),
    );
    expect(description.maxLines, 2);

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller!.viewportFraction, closeTo(0.84, 0.001));
    expect(find.bySemanticsLabel('추천 퀘스트 1 / 3'), findsOneWidget);
    expect(find.text('진행 중인 여행이 없어요.'), findsOneWidget);
    expect(find.text('새 여행 만들기'), findsOneWidget);
  });

  testWidgets('지역 화면은 같은 지역의 진행중 여행만 보여주고 상세로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = _FakeDomainRepository(
      _snapshot(
        journeys: [
          _journey(
            id: 'active-danyang',
            regionKey: 'danyang',
            title: '단양 여름 여행',
            status: 'in_progress',
            createdAt: DateTime(2026, 8, 19),
          ),
          _journey(
            id: 'completed-danyang',
            regionKey: 'danyang',
            title: '완료된 단양 여행',
            status: 'completed',
            createdAt: DateTime(2026, 8, 18),
          ),
          _journey(
            id: 'active-cheongju',
            regionKey: 'cheongju',
            title: '청주 여행',
            status: 'in_progress',
            createdAt: DateTime(2026, 8, 17),
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      _app(
        repository: repository,
        home: const RegionOverviewScreen(regionId: 'danyang'),
        routes: [
          GoRoute(
            path: '/journey/:journeyId',
            builder: (_, state) =>
                Text('여행 상세 ${state.pathParameters['journeyId']}'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('이 지역의 내 여행'), findsOneWidget);
    expect(find.text('단양 여름 여행'), findsOneWidget);
    expect(find.text('완료된 단양 여행'), findsNothing);
    expect(find.text('청주 여행'), findsNothing);
    expect(find.text('추천 퀘스트'), findsOneWidget);

    await tester.tap(find.text('단양 여름 여행'));
    await tester.pumpAndSettle();
    expect(find.text('여행 상세 active-danyang'), findsOneWidget);
  });

  testWidgets('진행 중 여행 상세는 진행도와 퀘스트 동작 및 수정 진입을 제공한다', (tester) async {
    final journey = _journey(
      id: 'active-danyang',
      regionKey: 'danyang',
      title: '단양 여름 여행',
      status: 'in_progress',
      createdAt: DateTime(2026, 8, 19),
    );
    final repository = _FakeDomainRepository(_snapshot(journeys: [journey]));
    await tester.pumpWidget(
      _app(
        repository: repository,
        home: const JourneyDetailScreen(journeyId: 'active-danyang'),
        routes: [
          GoRoute(
            path: '/region/:regionId/quests',
            builder: (_, state) =>
                Text('퀘스트 수정 ${state.uri.queryParameters['journeyId']}'),
          ),
          GoRoute(
            path: '/quest/:questId/verify',
            builder: (_, state) =>
                Text('퀘스트 인증 ${state.uri.queryParameters['journeyId']}'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('단양 여름 여행'), findsOneWidget);
    expect(find.text('2026.08.19 ~ 08.20'), findsOneWidget);
    expect(find.text('퀘스트 0/1'), findsOneWidget);
    expect(find.text('소백산 연화봉 전망대 인증'), findsOneWidget);
    expect(find.text('퀘스트 수정하기'), findsOneWidget);

    await tester.tap(find.text('소백산 연화봉 전망대 인증'));
    await tester.pumpAndSettle();
    expect(find.text('퀘스트 인증 active-danyang'), findsOneWidget);
  });

  testWidgets('완료 여행 상세는 읽기 전용이고 잘못된 여행 ID는 오류를 표시한다', (tester) async {
    final completed = _journey(
      id: 'completed-danyang',
      regionKey: 'danyang',
      title: '완료된 단양 여행',
      status: 'completed',
      createdAt: DateTime(2026, 8, 18),
    );
    final repository = _FakeDomainRepository(
      _snapshot(journeys: [completed], completedQuestKeys: const {'dy1'}),
    );
    await tester.pumpWidget(
      _app(
        repository: repository,
        home: const JourneyDetailScreen(journeyId: 'completed-danyang'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('퀘스트 1/1'), findsOneWidget);
    expect(find.text('퀘스트 수정하기'), findsNothing);

    await tester.pumpWidget(
      _app(
        repository: repository,
        home: const JourneyDetailScreen(journeyId: 'missing'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('여행을 찾을 수 없어요.'), findsOneWidget);
  });

  testWidgets('기존 여행의 퀘스트 저장 후 해당 여행 상세로 복귀한다', (tester) async {
    final journey = _journey(
      id: 'active-danyang',
      regionKey: 'danyang',
      title: '단양 여름 여행',
      status: 'in_progress',
      createdAt: DateTime(2026, 8, 19),
    );
    final repository = _FakeDomainRepository(_snapshot(journeys: [journey]));
    await tester.pumpWidget(
      _app(
        repository: repository,
        home: const RegionQuestSelectScreen(
          regionId: 'danyang',
          journeyId: 'active-danyang',
        ),
        routes: [
          GoRoute(
            path: '/journey/:journeyId',
            builder: (_, state) =>
                Text('수정 완료 ${state.pathParameters['journeyId']}'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('소백산 연화봉 전망대 인증'));
    await tester.pump();
    await tester.tap(find.text('퀘스트 추가하기 (1)'));
    await tester.pumpAndSettle();

    expect(repository.replacedJourneyId, 'active-danyang');
    expect(find.text('수정 완료 active-danyang'), findsOneWidget);
  });

  testWidgets('단독 경로인 여행 상세의 뒤로가기는 여행 목록으로 이동한다', (tester) async {
    final journey = _journey(
      id: 'active-danyang',
      regionKey: 'danyang',
      title: '단양 여름 여행',
      status: 'in_progress',
      createdAt: DateTime(2026, 8, 19),
    );
    final repository = _FakeDomainRepository(_snapshot(journeys: [journey]));
    await tester.pumpWidget(
      _app(
        repository: repository,
        home: const JourneyDetailScreen(journeyId: 'active-danyang'),
        routes: [
          GoRoute(path: '/travel', builder: (_, _) => const Text('여행 목록')),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.text('여행 목록'), findsOneWidget);
  });
}
