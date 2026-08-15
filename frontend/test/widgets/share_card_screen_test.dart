import 'dart:typed_data';

import 'package:colortrip/features/home/share_card_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('공유 카드가 DNA 설명을 표시하고 PNG 이미지를 저장한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    Uint8List? savedBytes;
    String? savedName;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shareImageSaverProvider.overrideWithValue((
            bytes, {
            required name,
          }) async {
            savedBytes = bytes;
            savedName = name;
          }),
        ],
        child: const MaterialApp(home: ShareCardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('지도 + DNA'), findsOneWidget);
    expect(tester.getSize(find.text('지도 + DNA')).height, lessThan(20));
    expect(find.text('자연탐험형 여행자'), findsOneWidget);
    expect(find.text('대자연 속에서 에너지를 얻고 조용한 힐링을 즐기는 탐험가예요.'), findsOneWidget);
    expect(find.text('🌿'), findsNothing);

    await tester.ensureVisible(find.text('이미지 저장'));
    await tester.tap(find.text('이미지 저장'));
    await tester.pump();
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 20 && savedBytes == null; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    expect(find.text('이미지 저장에 실패했어요. 다시 시도해주세요.'), findsNothing);
    expect(savedBytes, isNotNull);
    expect(
      savedBytes!.take(8),
      orderedEquals(const [137, 80, 78, 71, 13, 10, 26, 10]),
    );
    expect(savedName, startsWith('colortrip_share_'));
    expect(find.text('이미지가 저장되었어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
