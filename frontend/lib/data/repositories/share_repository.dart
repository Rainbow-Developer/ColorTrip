import 'package:dio/dio.dart';

/// 공유 카드 API 연동([030-share-card]) — 공유 스타일별 숏코드·링크를 발급받는다.
abstract class ShareRepository {
  Future<String> createShareLink(String shareStyle);
}

class DioShareRepository implements ShareRepository {
  const DioShareRepository(this._dio);

  final Dio _dio;

  @override
  Future<String> createShareLink(String shareStyle) async {
    final response = await _dio.post(
      '/shares',
      data: {'share_style': shareStyle},
    );
    // Envelope 포맷: {code: SUCCESS, status: 201, message: ..., data: {...}}
    final data = response.data['data'] as Map<String, dynamic>;
    return data['share_url'] as String;
  }
}
