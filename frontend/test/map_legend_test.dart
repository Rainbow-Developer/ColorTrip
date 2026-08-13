/// 지도 범례가 채색 집계 기준을 정확히 설명하는지 검증
/// ([docs/specs/055-journey-map-coloring], KAN-73 — CodeRabbit 리뷰 반영).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colortrip/core/constants.dart';
import 'package:colortrip/core/widgets/map_legend.dart';

void main() {
  testWidgets('범례는 완주가 아니라 "인증한 여행 수"를 기준으로 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MapLegend())),
    );

    // 채색 집계는 "퀘스트를 1개 이상 인증한 여행"이므로 완주(완료) 표현을 쓰지 않는다.
    expect(find.text('인증한 여행 수'), findsOneWidget);
    expect(find.text('여행 완료 횟수'), findsNothing);
    // 채도 cap(5)과 스와치 단계 수가 어긋나면 범례가 거짓말을 한다.
    expect(find.text('5회+'), findsOneWidget);
    expect(mapLegendColors.length, 5);
  });
}
