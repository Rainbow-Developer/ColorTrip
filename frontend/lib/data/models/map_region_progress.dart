/// `GET /users/me/map` 응답 1건 — 지역별 완료 개수([015-map-progress] 참고).
class MapRegionProgress {
  const MapRegionProgress({
    required this.regionId,
    required this.regionName,
    required this.completedCount,
    required this.completedJourneyCount,
  });

  factory MapRegionProgress.fromJson(Map<String, dynamic> json) {
    return MapRegionProgress(
      regionId: json['region_id'] as String,
      regionName: json['region_name'] as String,
      completedCount: json['completed_count'] as int,
      // 완료 여행 수는 나중에 추가된 필드라 배포 시차로 구버전 서버 응답에는 없을 수
      // 있다 — 없으면 0으로 안전 파싱한다([035-journey-map-coloring]).
      completedJourneyCount: json['completed_journey_count'] as int? ?? 0,
    );
  }

  final String regionId;
  final String regionName;

  /// 지역에서 완료한 퀘스트 개수 — 채색 기준에서는 빠졌지만 다른 통계·동기화에
  /// 그대로 쓰인다(하위호환, [035-journey-map-coloring] 비목표).
  final int completedCount;

  /// 지역에서 완료한 여행(여정) 수 — 지도 채색 기준([035-journey-map-coloring]).
  final int completedJourneyCount;
}
