import 'package:dio/dio.dart';

import '../models/festival.dart';

/// 지역별 행사·축제 조회 (docs/specs/095-festival-info).
///
/// 백엔드 프록시(`GET /api/v1/festivals?region_slug=`)가 TourAPI searchFestival2를
/// 실시간 조회해 진행 중·60일 이내 개막 예정 행사만 개막일순으로 내려준다.
abstract class FestivalRepository {
  Future<List<Festival>> byRegion(String regionId);
}

class DioFestivalRepository implements FestivalRepository {
  const DioFestivalRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Festival>> byRegion(String regionId) async {
    final response = await _dio.get(
      '/festivals',
      queryParameters: {'region_slug': regionId},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['data'] as List)
        .cast<Map<String, dynamic>>()
        .map(Festival.fromJson)
        .toList();
  }
}
