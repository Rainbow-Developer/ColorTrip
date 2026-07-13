import 'package:dio/dio.dart';

import '../models/map_region_progress.dart';

/// 지도 진행도 조회 인터페이스([020-frontend-map-sync] 참고).
abstract class MapRepository {
  Future<List<MapRegionProgress>> fetchMyMap();
}

class DioMapRepository implements MapRepository {
  const DioMapRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<MapRegionProgress>> fetchMyMap() async {
    final response = await _dio.get('/users/me/map');
    final data = response.data as Map<String, dynamic>;
    final items = (data['data'] as Map<String, dynamic>)['items'] as List;
    return items
        .cast<Map<String, dynamic>>()
        .map(MapRegionProgress.fromJson)
        .toList();
  }
}
