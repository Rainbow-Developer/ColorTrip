import 'package:dio/dio.dart';

String apiErrorMessage(Object error, String fallback) {
  if (error is! DioException) return fallback;
  final data = error.response?.data;
  if (data is! Map) return fallback;
  final message = data['message'];
  if (message is String && message.trim().isNotEmpty) {
    return message.trim();
  }
  return fallback;
}
