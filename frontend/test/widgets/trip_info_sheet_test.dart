import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colortrip/core/widgets/trip_info_sheet.dart';

/// 여행 이름·기간 입력 시트의 하단탭 가림 회귀 테스트(KAN-103).
/// 셸 탭 화면(중첩 내비게이터)에서 열어도 시트가 루트 내비게이터에 쌓여
/// 떠 있는 하단탭(extendBody 셸 바) 위에 그려져야 한다.
void main() {
  testWidgets('시트는 중첩 내비게이터가 아니라 루트 내비게이터에 뜬다', (tester) async {
    final rootNavKey = GlobalKey<NavigatorState>();
    final branchNavKey = GlobalKey<NavigatorState>();
    late BuildContext branchContext;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavKey,
        home: Navigator(
          key: branchNavKey,
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (context) {
              branchContext = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      ),
    );

    showTripInfoSheet(
      context: branchContext,
      initialName: '단양 여행',
      title: '여행 정보를 입력해주세요',
      submitLabel: '여행 시작하기',
    );
    await tester.pumpAndSettle();

    expect(find.text('여행 시작하기'), findsOneWidget);
    // 루트에 시트 라우트가 쌓이고, 브랜치(셸 탭) 내비게이터에는 쌓이지 않는다.
    expect(rootNavKey.currentState!.canPop(), isTrue);
    expect(branchNavKey.currentState!.canPop(), isFalse);
  });

  testWidgets('제출 버튼은 하단 SafeArea 안에 있다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TripInfoSheet(initialName: '단양 여행')),
      ),
    );

    // 시트 내용이 SafeArea로 감싸져 시스템 내비게이션 바를 피한다.
    expect(
      find.ancestor(
        of: find.widgetWithText(ElevatedButton, '저장하기'),
        matching: find.byType(SafeArea),
      ),
      findsWidgets,
    );
  });
}
