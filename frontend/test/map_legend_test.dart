/// 지도 범례가 채색 집계 기준을 정확히 설명하는지 검증
/// ([docs/specs/055-journey-map-coloring], KAN-73 — CodeRabbit 리뷰 반영).
///
/// KAN-69에서 인라인 스와치가 "지역별 색상 팔레트 보기" 팝업으로 바뀌면서,
/// 기준 문구도 팝업 안으로 옮겨졌다. 검증 대상은 그대로 "범례가 거짓말하지 않는가"다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colortrip/core/widgets/map_legend.dart';
import 'package:colortrip/data/static/regions_data.dart';

void main() {
  testWidgets('범례는 팔레트 팝업으로 진입한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MapLegend())),
    );

    expect(find.text('지역별 색상 팔레트 보기'), findsOneWidget);
    // 팝업을 열기 전에는 팔레트가 노출되지 않는다.
    expect(find.text('지역별 색상 팔레트'), findsNothing);
  });

  testWidgets('팝업은 완주가 아니라 "인증한 여행 수"를 기준으로 설명한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MapLegend())),
    );

    await tester.tap(find.text('지역별 색상 팔레트 보기'));
    await tester.pumpAndSettle();

    expect(find.text('지역별 색상 팔레트'), findsOneWidget);
    // 채색 집계는 "퀘스트를 1개 이상 인증한 여행"이므로 완주(완료) 표현을 쓰지 않는다.
    // 채도 cap(5)과 설명의 단계 수가 어긋나면 범례가 거짓말을 한다.
    expect(find.text('왼쪽부터 인증한 여행 수 1회 → 5회예요 ✨'), findsOneWidget);
    expect(find.textContaining('완료 횟수'), findsNothing);
    expect(find.textContaining('완주'), findsNothing);
  });

  testWidgets('팝업은 11개 지역 팔레트를 모두 보여준다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MapLegend())),
    );

    await tester.tap(find.text('지역별 색상 팔레트 보기'));
    await tester.pumpAndSettle();

    for (final region in kRegionsInMapOrder) {
      expect(
        find.text(region.name),
        findsOneWidget,
        reason: '${region.name} 팔레트가 빠졌다',
      );
    }
  });
}
