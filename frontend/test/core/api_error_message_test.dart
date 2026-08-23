import 'package:colortrip/core/network/api_error_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('서버 envelope message를 사용자 문구로 사용한다', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/journeys'),
      response: Response(
        requestOptions: RequestOptions(path: '/journeys'),
        data: {
          'code': 'VALIDATION_ERROR',
          'message': '이미 해당 기간에 등록된 여행이 있습니다.',
        },
        statusCode: 422,
      ),
      type: DioExceptionType.badResponse,
    );

    expect(apiErrorMessage(error, 'fallback'), '이미 해당 기간에 등록된 여행이 있습니다.');
  });

  test('서버 message가 없으면 fallback을 사용한다', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/journeys'),
      type: DioExceptionType.connectionError,
    );

    expect(apiErrorMessage(error, 'fallback'), 'fallback');
  });
}
