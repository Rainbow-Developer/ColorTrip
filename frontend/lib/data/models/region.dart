/// 충북 11개 시·군 지도 데이터. `path`는 SVG path(viewBox "10 10 480 460") 좌표계.
class Region {
  const Region({
    required this.id,
    required this.name,
    required this.path,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String path;

  /// 지역 대표 이미지(TourAPI) — 없으면 placeholder 표시
  /// (docs/specs/045-quest-region-images).
  final String? imageUrl;
}
