import 'package:dio/dio.dart';

import '../models/home_recommendation.dart';

/// 홈 DNA 지역 추천 조회 인터페이스([040-home-region-recommendation] 참고).
abstract class HomeRepository {
  /// 추천 지역이 FE 정적 지도에 없으면 null(호출부는 정적 폴백). 네트워크·서버 오류는
  /// 예외를 그대로 던진다 — 폴백 여부는 호출부(provider)가 정한다.
  Future<HomeRecommendation?> fetchRecommendation();
}

class DioHomeRepository implements HomeRepository {
  const DioHomeRepository(this._dio);

  final Dio _dio;

  @override
  Future<HomeRecommendation?> fetchRecommendation() async {
    final response = await _dio.get('/home/recommendation');
    // Envelope 포맷: {code: SUCCESS, status: 200, message: ..., data: {...}}
    final data = response.data as Map<String, dynamic>;
    return HomeRecommendation.fromJson(data['data'] as Map<String, dynamic>);
  }
}
