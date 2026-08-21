import 'package:dio/dio.dart';

import '../models/place_detail.dart';

/// TourAPI 장소 정보 실시간 조회 — 백엔드 places 프록시를 호출한다
/// (docs/specs/090-realtime-tour-place-info). 앱은 TourAPI를 직접 부르지 않는다.
abstract class PlaceRepository {
  /// 지역의 관광지 대표 이미지 맵(contentId → 이미지 URL).
  Future<Map<String, String>> regionImages(String regionSlug);

  /// 장소 상세(이미지·소개문·운영정보). 실패한 필드는 null.
  Future<PlaceDetail> detail(String contentId, String contentTypeId);
}

class DioPlaceRepository implements PlaceRepository {
  const DioPlaceRepository(this._dio);

  final Dio _dio;

  @override
  Future<Map<String, String>> regionImages(String regionSlug) async {
    final response = await _dio.get(
      '/places',
      queryParameters: {'region_slug': regionSlug},
    );
    final data = response.data as Map<String, dynamic>;
    final items = (data['data'] as List).cast<Map<String, dynamic>>();
    return {
      for (final item in items)
        item['content_id'] as String: item['image_url'] as String,
    };
  }

  @override
  Future<PlaceDetail> detail(String contentId, String contentTypeId) async {
    final response = await _dio.get(
      '/places/$contentId',
      queryParameters: {'content_type_id': contentTypeId},
    );
    final data = response.data as Map<String, dynamic>;
    return PlaceDetail.fromJson(data['data'] as Map<String, dynamic>);
  }
}
