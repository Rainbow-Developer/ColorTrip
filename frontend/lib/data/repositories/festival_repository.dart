import '../models/festival.dart';

/// 지역별 행사·축제 조회 (docs/specs/095-festival-info).
///
/// 반환 규칙: 오늘 기준 진행 중이거나 [upcomingWindowDays]일 이내 개막 예정인
/// 행사만, 개막일 오름차순으로.
abstract class FestivalRepository {
  static const upcomingWindowDays = 60;

  Future<List<Festival>> byRegion(String regionId);
}

/// 시연용 스텁 — 백엔드 searchFestival2 프록시(095 스펙 2단계)가 생기면
/// Dio 구현체로 provider override를 교체하고 이 클래스는 제거한다.
/// 샘플은 실존 축제명 기반이지만 기간·내용은 시연용 임의 값이다.
class StubFestivalRepository implements FestivalRepository {
  const StubFestivalRepository();

  static final _samples = <String, List<Festival>>{
    'danyang': [
      Festival(
        id: 'fest-dy-1',
        title: '단양 온달문화축제',
        placeName: '온달관광지 일원',
        startDate: DateTime(2026, 10, 16),
        endDate: DateTime(2026, 10, 19),
        lat: 37.0578,
        lng: 128.4801,
        description: '온달장군과 평강공주 설화를 테마로 한 단양 대표 축제. 거리 퍼레이드와 전통 공연이 열립니다.',
      ),
    ],
    'jecheon': [
      Festival(
        id: 'fest-jc-1',
        title: '제천국제음악영화제',
        placeName: '제천 시내 일원',
        startDate: DateTime(2026, 8, 13),
        endDate: DateTime(2026, 8, 31),
        lat: 37.1326,
        lng: 128.1910,
        description: '음악과 영화가 만나는 국내 유일의 음악영화제. 의림지 야외 상영과 거리 공연이 함께합니다.',
      ),
    ],
    'cheongju': [
      Festival(
        id: 'fest-cj-1',
        title: '청주공예비엔날레',
        placeName: '문화제조창 일원',
        startDate: DateTime(2026, 9, 4),
        endDate: DateTime(2026, 11, 1),
        lat: 36.6659,
        lng: 127.4890,
        description: '세계 최초·최대 규모의 공예 비엔날레. 옛 담배공장을 재생한 문화제조창에서 열립니다.',
      ),
    ],
  };

  @override
  Future<List<Festival>> byRegion(String regionId) async {
    final today = DateTime.now();
    final items =
        (_samples[regionId] ?? const <Festival>[])
            .where(
              (f) =>
                  f.isOngoing(today) ||
                  (f.daysUntilStart(today) > 0 &&
                      f.daysUntilStart(today) <=
                          FestivalRepository.upcomingWindowDays),
            )
            .toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return items;
  }
}
