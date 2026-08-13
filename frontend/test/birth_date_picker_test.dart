/// 생년월일 3단 휠 피커 — 유효 범위 밖 날짜를 고를 수 없는지 검증 (KAN-73).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colortrip/core/widgets/birth_date_picker.dart';

/// 피커를 열고 선택 결과를 담아두는 최소 하네스.
class _Host extends StatefulWidget {
  const _Host({required this.firstDate, required this.lastDate, this.initial});

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  DateTime? picked;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final result = await showBirthDatePicker(
                    context: context,
                    initialDate: widget.initial ?? widget.lastDate,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                  );
                  setState(() => picked = result);
                },
                child: const Text('열기'),
              ),
              Text('picked=${picked?.toIso8601String() ?? '-'}'),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('연·월·일 휠 3개를 띄우고 선택 결과를 반환한다', (tester) async {
    await tester.pumpWidget(
      _Host(firstDate: DateTime(1906), lastDate: DateTime(2026, 8, 13)),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPicker), findsNWidgets(3));

    await tester.tap(find.text('선택 완료'));
    await tester.pumpAndSettle();
    expect(find.text('picked=2026-08-13T00:00:00.000'), findsOneWidget);
  });

  testWidgets('연도를 끝까지 올려도 lastDate 이후 날짜는 나오지 않는다', (tester) async {
    // 마지막 연도(2026)에서는 8월까지만, 8월에서는 13일까지만 고를 수 있어야 한다.
    final lastDate = DateTime(2026, 8, 13);
    await tester.pumpWidget(
      _Host(
        firstDate: DateTime(1906),
        lastDate: lastDate,
        initial: DateTime(1990, 12, 31),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    // 연도 휠을 위로 크게 밀어 마지막 연도까지 이동시킨다.
    await tester.drag(
      find.byType(CupertinoPicker).first,
      const Offset(0, -4000),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('선택 완료'));
    await tester.pumpAndSettle();

    final text = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((t) => t.startsWith('picked='));
    final picked = DateTime.parse(text.substring('picked='.length));
    expect(
      picked.isAfter(lastDate),
      isFalse,
      reason: '휠에 유효 범위만 노출돼야 한다 (선택된 값: $picked)',
    );
  });

  testWidgets('initialDate가 범위를 벗어나면 경계 값으로 시작한다', (tester) async {
    final lastDate = DateTime(2026, 8, 13);
    await tester.pumpWidget(
      _Host(
        firstDate: DateTime(2000),
        lastDate: lastDate,
        initial: DateTime(2030, 5, 5), // 미래 — lastDate로 clamp
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('선택 완료'));
    await tester.pumpAndSettle();
    expect(find.text('picked=2026-08-13T00:00:00.000'), findsOneWidget);
  });

  testWidgets('firstDate가 연중이어도 연도만 옮기면 월·일이 유지된다', (tester) async {
    // 범위 보정(jumpToItem)이 낡은 목록으로 콜백을 되부르면 월·일이 연쇄 이동한다.
    // 실제 호출부(minimumBirthDate)는 1월 1일이라 드러나지 않지만 잠재 버그였다.
    await tester.pumpWidget(
      _Host(
        firstDate: DateTime(1980, 6, 15),
        lastDate: DateTime(2030, 12, 31),
        initial: DateTime(1980, 6, 20),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    // 연도 휠만 한 칸(1980 → 1981) 올린다.
    await tester.drag(find.byType(CupertinoPicker).first, const Offset(0, -40));
    await tester.pumpAndSettle();

    await tester.tap(find.text('선택 완료'));
    await tester.pumpAndSettle();

    expect(find.text('picked=1981-06-20T00:00:00.000'), findsOneWidget);
  });
}
