/// 관광지 정보 실시간 조회(docs/specs/090-realtime-tour-place-info) —
/// [QuestImage]가 지역 이미지 맵에서 tourContentId로 URL을 해석하는 경로와,
/// 조회 실패·contentId 없음 시 placeholder 폴백을 검증한다.
/// 네트워크 이미지는 실제로 로드하지 않는다(위젯 존재와 URL만 확인).
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colortrip/core/widgets/quest_image.dart';
import 'package:colortrip/data/models/place_detail.dart';
import 'package:colortrip/data/models/quest.dart';
import 'package:colortrip/data/repositories/place_repository.dart';
import 'package:colortrip/state/repository_providers.dart';

/// 지정한 맵/상세만 돌려주는 대역 — throwOnImages면 조회 실패 경로를 검증한다.
class _FakePlaceRepository implements PlaceRepository {
  _FakePlaceRepository({this.images = const {}, this.throwOnImages = false});

  final Map<String, String> images;
  final bool throwOnImages;

  @override
  Future<Map<String, String>> regionImages(String regionSlug) async {
    if (throwOnImages) throw Exception('TourAPI down');
    return images;
  }

  @override
  Future<PlaceDetail> detail(String contentId, String contentTypeId) async =>
      PlaceDetail(contentId: contentId);
}

const _quest = Quest(
  id: 'dy6',
  region: 'danyang',
  type: 'nature',
  title: '중선암 풍경 담기',
  place: '중선암',
  verify: 'photo',
  reward: 80,
  conditions: ['중선암에서 촬영'],
  tourContentId: '1626649',
  tourContentTypeId: '12',
);

Widget _wrap(PlaceRepository repo, Quest quest) => ProviderScope(
  overrides: [placeRepositoryProvider.overrideWith((ref) => repo)],
  child: MaterialApp(
    home: Scaffold(body: QuestImage(quest: quest, width: 44, height: 44)),
  ),
);

void main() {
  group('QuestImage', () {
    testWidgets('지역 이미지 맵에서 tourContentId로 URL을 찾아 그린다', (tester) async {
      final repo = _FakePlaceRepository(
        images: {'1626649': 'https://tong.example/1626649.jpg'},
      );
      await tester.pumpWidget(_wrap(repo, _quest));
      await tester.pump(); // FutureProvider 해소

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.imageUrl, 'https://tong.example/1626649.jpg');
    });

    testWidgets('조회 실패 시 네트워크 위젯 없이 placeholder를 그린다', (tester) async {
      await tester.pumpWidget(
        _wrap(_FakePlaceRepository(throwOnImages: true), _quest),
      );
      await tester.pump();

      expect(find.byType(CachedNetworkImage), findsNothing);
    });

    testWidgets('tourContentId 없는 수제 퀘스트는 조회 없이 placeholder를 그린다', (
      tester,
    ) async {
      const handmade = Quest(
        id: 'dy1',
        region: 'danyang',
        type: 'nature',
        title: '소백산 연화봉 전망대 인증',
        place: '소백산 연화봉',
        verify: 'photo',
        reward: 120,
        desc: '능선을 배경으로 인증샷을 남겨보세요.',
        conditions: ['연화봉 전망대 도착 후 촬영'],
      );
      await tester.pumpWidget(_wrap(_FakePlaceRepository(), handmade));
      await tester.pump();

      expect(find.byType(CachedNetworkImage), findsNothing);
    });
  });

  group('PlaceDetail.fromJson', () {
    test('운영정보 포함 응답을 파싱한다', () {
      final detail = PlaceDetail.fromJson(const {
        'content_id': '100',
        'image_url': 'https://tong.example/100.jpg',
        'overview': '단양팔경 중 하나.',
        'operation_info': {'usetime': '09:00~18:00', 'restdate': '연중무휴'},
      });
      expect(detail.imageUrl, 'https://tong.example/100.jpg');
      expect(detail.overview, '단양팔경 중 하나.');
      expect(detail.operationInfo?.usetime, '09:00~18:00');
      expect(detail.operationInfo?.restdate, '연중무휴');
    });

    test('실패 응답(null 필드)을 파싱한다', () {
      final detail = PlaceDetail.fromJson(const {
        'content_id': '100',
        'image_url': null,
        'overview': null,
        'operation_info': null,
      });
      expect(detail.imageUrl, isNull);
      expect(detail.overview, isNull);
      expect(detail.operationInfo, isNull);
    });
  });
}
