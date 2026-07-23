/// KAN-28 기능 검증 — 홈 추천 배너 · 여행 시작 이름/날짜 입력 시트 · 여행 목록 표시.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:colortrip/data/models/region.dart';
import 'package:colortrip/data/static/quests_data.dart';
import 'package:colortrip/data/static/regions_data.dart';
import 'package:colortrip/features/home/home_screen.dart';
import 'package:colortrip/features/quests/region_quest_select_screen.dart';
import 'package:colortrip/features/travel/travel_list_screen.dart';
import 'package:colortrip/state/onboarding_tour_notifier.dart';
import 'package:colortrip/state/progress_notifier.dart';
import 'package:colortrip/state/progress_state.dart';

/// 온보딩 투어는 main.dart에서 초기값을 주입해야 하는 프로바이더라 테스트에서도 주입한다.
/// 코치마크가 화면을 덮지 않도록 "완료" 상태로 둔다.
final _tourDoneOverride = onboardingTourProvider.overrideWith(
  () => OnboardingTourNotifier(
    const OnboardingTourState(step: kOnboardingTotalSteps, skipped: true),
  ),
);

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
  testWidgets('퀘스트 정적 데이터는 11개 시·군 각 20개씩 220개다', (tester) async {
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

  testWidgets('홈에 DNA 유형 기반 추천 여행지 배너가 뜬다', (tester) async {
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    // 기본 DNA(nature)·초기 상태(모든 지역 미시작) 기준, 배너 로직과 같은 방식으로
    // 기대 지역을 데이터에서 계산한다(퀘스트 데이터가 늘어나도 테스트가 깨지지 않게).
    Region? expected;
    var bestMatch = -1;
    var bestTotal = -1;
    for (final region in kRegionsInMapOrder) {
      final quests = questsByRegion(region.id);
      final match = quests.where((q) => q.type == 'nature').length;
      if (match > bestMatch ||
          (match == bestMatch && quests.length > bestTotal)) {
        expected = region;
        bestMatch = match;
        bestTotal = quests.length;
      }
    }

    expect(find.textContaining('추천 여행지'), findsOneWidget);
    expect(find.text(expected!.name), findsWidgets);
    expect(find.text('자연탐험 퀘스트 $bestMatch개가 기다리고 있어요'), findsOneWidget);
  });

  testWidgets('여행 시작하기 시 이름·날짜 입력 시트를 거쳐 여행이 등록된다', (tester) async {
    // 전체 화면 날짜 피커의 날짜 셀이 기본 서피스(800x600) 밖으로 밀려나 탭이 닿지 않는다.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: [_tourDoneOverride]);
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

  testWidgets('기간 표기는 같은 해면 연도를 한 번만 쓴다', (tester) async {
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
