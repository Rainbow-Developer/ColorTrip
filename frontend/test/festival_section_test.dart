/// 지역 행사·축제 섹션(docs/specs/095-festival-info) — 카드 렌더링과
/// 빈 결과 시 섹션 숨김, Festival 날짜 판정을 검증한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colortrip/data/models/festival.dart';
import 'package:colortrip/data/repositories/festival_repository.dart';
import 'package:colortrip/features/quests/region_overview_screen.dart';
import 'package:colortrip/state/repository_providers.dart';

class _FakeFestivalRepository implements FestivalRepository {
  _FakeFestivalRepository(this.festivals);

  final List<Festival> festivals;

  @override
  Future<List<Festival>> byRegion(String regionId) async => festivals;
}

Widget _wrap(FestivalRepository repo) => ProviderScope(
  overrides: [festivalRepositoryProvider.overrideWith((ref) => repo)],
  child: const MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: FestivalSection(regionId: 'danyang')),
    ),
  ),
);

void main() {
  group('FestivalSection', () {
    testWidgets('진행 중 행사는 카드와 "진행 중" 배지로 그린다', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        _wrap(
          _FakeFestivalRepository([
            Festival(
              id: 'f1',
              title: '제천국제음악영화제',
              placeName: '제천 시내 일원',
              startDate: now.subtract(const Duration(days: 1)),
              endDate: now.add(const Duration(days: 5)),
            ),
          ]),
        ),
      );
      await tester.pump();

      expect(find.text('진행 중 행사·축제'), findsOneWidget);
      expect(find.text('제천국제음악영화제'), findsOneWidget);
      expect(find.text('진행 중'), findsOneWidget);
    });

    testWidgets('개막 예정 행사는 D-n 배지를 단다', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        _wrap(
          _FakeFestivalRepository([
            Festival(
              id: 'f2',
              title: '단양 온달문화축제',
              placeName: '온달관광지 일원',
              startDate: now.add(const Duration(days: 3)),
              endDate: now.add(const Duration(days: 6)),
            ),
          ]),
        ),
      );
      await tester.pump();

      expect(find.text('D-3'), findsOneWidget);
    });

    testWidgets('행사가 없으면 섹션 자체를 그리지 않는다', (tester) async {
      await tester.pumpWidget(_wrap(_FakeFestivalRepository(const [])));
      await tester.pump();

      expect(find.text('진행 중 행사·축제'), findsNothing);
    });
  });

  group('Festival 날짜 판정', () {
    final festival = Festival(
      id: 'f',
      title: 't',
      placeName: 'p',
      startDate: DateTime(2026, 10, 16),
      endDate: DateTime(2026, 10, 19),
    );

    test('시작일·종료일 당일도 진행 중이다', () {
      expect(festival.isOngoing(DateTime(2026, 10, 16, 23)), isTrue);
      expect(festival.isOngoing(DateTime(2026, 10, 19, 1)), isTrue);
      expect(festival.isOngoing(DateTime(2026, 10, 20)), isFalse);
    });

    test('daysUntilStart는 시작 후 0을 반환한다', () {
      expect(festival.daysUntilStart(DateTime(2026, 10, 13)), 3);
      expect(festival.daysUntilStart(DateTime(2026, 10, 17)), 0);
    });

    test('Festival.fromJson은 백엔드 응답을 파싱한다', () {
      final festival = Festival.fromJson(const {
        'id': '1',
        'title': '단양 온달문화축제',
        'place_name': '충청북도 단양군 영춘면',
        'start_date': '2026-10-16',
        'end_date': '2026-10-19',
        'poster_url': 'https://tong.example/poster.jpg',
        'lat': 37.0578,
        'lng': 128.4801,
      });
      expect(festival.title, '단양 온달문화축제');
      expect(festival.startDate, DateTime(2026, 10, 16));
      expect(festival.posterUrl, 'https://tong.example/poster.jpg');
      expect(festival.lat, 37.0578);
    });
  });
}
