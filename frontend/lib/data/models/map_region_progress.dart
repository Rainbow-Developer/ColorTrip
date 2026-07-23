/// `GET /users/me/map` 응답 1건 — 지역별 완료 개수([015-map-progress] 참고).
class MapRegionProgress {
  const MapRegionProgress({
    required this.regionId,
    required this.regionName,
    required this.completedCount,
  });

  factory MapRegionProgress.fromJson(Map<String, dynamic> json) {
    return MapRegionProgress(
      regionId: json['region_id'] as String,
      regionName: json['region_name'] as String,
      completedCount: json['completed_count'] as int,
    );
  }

  final String regionId;
  final String regionName;
  final int completedCount;
}
