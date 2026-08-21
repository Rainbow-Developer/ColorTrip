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
      ),
    ],
    'jecheon': [
      Festival(
        id: 'fest-jc-1',
        title: '제천국제음악영화제',
        placeName: '제천 시내 일원',
        startDate: DateTime(2026, 8, 13),
        endDate: DateTime(2026, 8, 31),
      ),
    ],
    'cheongju': [
      Festival(
        id: 'fest-cj-1',
        title: '청주공예비엔날레',
        placeName: '문화제조창 일원',
        startDate: DateTime(2026, 9, 4),
        endDate: DateTime(2026, 11, 1),
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
