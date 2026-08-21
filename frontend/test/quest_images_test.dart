/// 퀘스트·지역 이미지(docs/specs/045-quest-region-images) — [AppNetworkImage]의
/// placeholder 폴백과 퀘스트 목록의 이미지 없는 경로를 검증한다.
///
/// 네트워크 이미지는 테스트에서 실제로 로드하지 않는다 — 썸네일 URL은 이제 TourAPI
/// 실시간 조회([090] QuestImage)로 오므로, 목록 테스트는 조회 없는 placeholder 경로만 본다.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:colortrip/core/constants.dart';
import 'package:colortrip/core/widgets/app_network_image.dart';
import 'package:colortrip/data/models/quest.dart';
import 'package:colortrip/data/repositories/quest_repository.dart';
import 'package:colortrip/data/static/quests_data.dart';
import 'package:colortrip/features/quests/quest_list_screen.dart';
import 'package:colortrip/state/repository_providers.dart';

/// 정적 퀘스트를 imageUrl 없이 복제한 저장소 — 보강 스크립트가 정적 데이터에 URL을
/// 채워 넣어도 이 테스트는 항상 "이미지 없는" 경로를 검증한다.
class _NoImageQuestRepository implements QuestRepository {
  final List<Quest> _quests = [
    for (final q in kQuests)
      Quest(
        id: q.id,
        region: q.region,
        type: q.type,
        title: q.title,
        place: q.place,
        verify: q.verify,
        reward: q.reward,
        desc: q.desc,
        conditions: q.conditions,
        quizQuestion: q.quizQuestion,
        quizAnswer: q.quizAnswer,
        verifyRadius: q.verifyRadius,
        // imageUrl·lat·lng는 의도적으로 비워 둔다.
      ),
  ];

  @override
  List<Quest> all() => _quests;

  @override
  Quest? byId(String id) {
    for (final q in _quests) {
      if (q.id == id) return q;
    }
    return null;
  }

  @override
  List<Quest> byRegion(String regionId) =>
      _quests.where((q) => q.region == regionId).toList();

  @override
  List<Quest> byType(String type) =>
      _quests.where((q) => q.type == type).toList();
}

/// 화면 하나를 GoRouter·ko locale과 함께 감싼다. 퀘스트 저장소를 넘기면 그것으로
/// 덮어써(override) 이미지 없는 정적 데이터 경로를 검증할 수 있다.
Widget _wrapScreen(Widget child, {QuestRepository? questRepository}) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [GoRoute(path: '/test', builder: (_, _) => child)],
  );
  return ProviderScope(
    overrides: [
      if (questRepository != null)
        questRepositoryProvider.overrideWith((ref) => questRepository),
    ],
    child: MaterialApp.router(
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    ),
  );
}

Finder _placeholderBox() => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      ((w.decoration! as BoxDecoration).gradient as LinearGradient?)
              ?.colors
              .first ==
          AppColors.imagePlaceholderBg,
);

void main() {
  group('AppNetworkImage', () {
    testWidgets('url이 null이면 네트워크 위젯 없이 이모지 placeholder를 그린다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppNetworkImage(
                url: null,
                width: 48,
                height: 48,
                borderRadius: BorderRadius.all(Radius.circular(24)),
                placeholderEmoji: '🌲',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.text('🌲'), findsOneWidget);
      expect(_placeholderBox(), findsOneWidget);
      // borderRadius가 있으면 ClipRRect로 감싼다.
      expect(
        find.descendant(
          of: find.byType(AppNetworkImage),
          matching: find.byType(ClipRRect),
        ),
        findsOneWidget,
      );
    });

    testWidgets('url이 빈 문자열이면 텍스트 placeholder로 폴백한다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 200,
                child: AppNetworkImage(url: '', placeholderText: '관광지 이미지'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.text('관광지 이미지'), findsOneWidget);
      expect(_placeholderBox(), findsOneWidget);
      // borderRadius가 없으면 자체 ClipRRect 없이 그린다(바깥 클립에 맡기는 경우).
      expect(
        find.descendant(
          of: find.byType(AppNetworkImage),
          matching: find.byType(ClipRRect),
        ),
        findsNothing,
      );
    });

    testWidgets('이모지·텍스트가 없으면 풍경 아이콘 placeholder를 그린다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppNetworkImage(
                url: null,
                width: 44,
                height: 44,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(_placeholderBox(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppNetworkImage),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });
  });

  testWidgets('퀘스트 목록은 이미지 없는 데이터로 크래시 없이 렌더된다', (tester) async {
    final repo = _NoImageQuestRepository();
    await tester.pumpWidget(
      _wrapScreen(const QuestListScreen(), questRepository: repo),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // 네트워크 이미지는 하나도 만들어지지 않고, 타일 leading은 전부 placeholder다.
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(AppNetworkImage), findsWidgets);
    expect(_placeholderBox(), findsWidgets);

    // 첫 퀘스트 타일: 제목과 유형 이모지 placeholder가 보인다.
    final first = repo.all().first;
    final emoji = questTypeStyles[first.type]?.emoji ?? '📍';
    expect(find.text(first.title), findsOneWidget);
    expect(find.text(emoji), findsWidgets);
  });
}
