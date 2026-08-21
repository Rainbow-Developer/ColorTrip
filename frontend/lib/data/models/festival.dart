/// 지역 행사·축제 1건 (docs/specs/095-festival-info).
///
/// 포스터가 없으면 placeholder를 표시한다. 날짜는 로컬 자정 기준으로 비교한다.
class Festival {
  const Festival({
    required this.id,
    required this.title,
    required this.placeName,
    required this.startDate,
    required this.endDate,
    this.posterUrl,
  });

  final String id;
  final String title;
  final String placeName;
  final DateTime startDate;
  final DateTime endDate;
  final String? posterUrl;

  /// [today] 기준 진행 중인지 (시작일 ≤ 오늘 ≤ 종료일).
  bool isOngoing(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    return !day.isBefore(_dayOf(startDate)) && !day.isAfter(_dayOf(endDate));
  }

  /// 개막까지 남은 일수 — 이미 시작했으면 0.
  int daysUntilStart(DateTime today) {
    final diff = _dayOf(
      startDate,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    return diff > 0 ? diff : 0;
  }

  static DateTime _dayOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
