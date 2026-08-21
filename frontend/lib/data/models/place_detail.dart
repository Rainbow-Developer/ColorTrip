/// TourAPI 장소 상세 — `GET /api/v1/places/{content_id}` 응답
/// (docs/specs/090-realtime-tour-place-info). 실시간 조회라 저장하지 않는다.
class PlaceDetail {
  const PlaceDetail({
    required this.contentId,
    this.imageUrl,
    this.overview,
    this.operationInfo,
  });

  factory PlaceDetail.fromJson(Map<String, dynamic> json) => PlaceDetail(
    contentId: json['content_id'] as String,
    imageUrl: json['image_url'] as String?,
    overview: json['overview'] as String?,
    operationInfo: json['operation_info'] == null
        ? null
        : PlaceOperationInfo.fromJson(
            json['operation_info'] as Map<String, dynamic>,
          ),
  );

  final String contentId;
  final String? imageUrl;
  final String? overview;
  final PlaceOperationInfo? operationInfo;
}

/// 운영정보 — 백엔드가 detailIntro2의 유형별 필드를 공통 이름으로 정규화한 값.
class PlaceOperationInfo {
  const PlaceOperationInfo({this.usetime, this.restdate});

  factory PlaceOperationInfo.fromJson(Map<String, dynamic> json) =>
      PlaceOperationInfo(
        usetime: json['usetime'] as String?,
        restdate: json['restdate'] as String?,
      );

  final String? usetime;
  final String? restdate;
}
