import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../models/verification.dart';

/// 퀘스트 인증 API 인터페이스(docs/specs/050-quest-verification).
///
/// 사진 AI 판정·QR 서명 검증만 서버를 호출한다. 위치(GPS) 인증은 온디바이스
/// 거리 계산으로 끝나므로 여기에 메서드가 없고, 앞으로도 좌표를 서버로 보내는
/// API를 추가해서는 안 된다(location-law-review.md — 위치기반서비스사업 신고 대상).
abstract class VerificationRepository {
  /// 사진 + 퀘스트 맥락(제목·장소·조건)을 보내 비전 모델 판정을 받는다.
  Future<PhotoVerdict> verifyPhoto({
    required Uint8List bytes,
    required String filename,
    required String title,
    required String place,
    required List<String> conditions,
  });

  /// 스캔한 QR 페이로드(`colortrip:quest:{id}:{서명16자}`)를 서버가 검증한다.
  /// 서명 검증은 전적으로 서버 몫 — FE는 rawValue를 그대로 전달한다.
  Future<QrVerdict> verifyQr({
    required String payload,
    required String questId,
  });
}

class DioVerificationRepository implements VerificationRepository {
  const DioVerificationRepository(this._dio);

  final Dio _dio;

  @override
  Future<PhotoVerdict> verifyPhoto({
    required Uint8List bytes,
    required String filename,
    required String title,
    required String place,
    required List<String> conditions,
  }) async {
    final form = FormData.fromMap({
      'title': title,
      'place': place,
      // 서버 스펙: 조건 목록은 줄바꿈 구분 문자열 하나로 보낸다.
      'conditions': conditions.join('\n'),
      'image': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: _imageMediaType(filename),
      ),
    });
    final response = await _dio.post(
      '/verifications/photo',
      data: form,
      // 업로드(최대 5MB)·비전 모델 판정은 기본 10초보다 오래 걸릴 수 있어 여유를 준다.
      options: Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    // Envelope 언랩 패턴([map_repository.dart] 참고): {code, status, message, data}.
    final data = response.data as Map<String, dynamic>;
    return PhotoVerdict.fromJson(data['data'] as Map<String, dynamic>);
  }

  @override
  Future<QrVerdict> verifyQr({
    required String payload,
    required String questId,
  }) async {
    final response = await _dio.post(
      '/verifications/qr',
      data: {'payload': payload, 'quest_id': questId},
    );
    final data = response.data as Map<String, dynamic>;
    return QrVerdict.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// 파일 확장자로 이미지 MIME 타입을 정한다 — 미지정 시 octet-stream으로 가서
  /// 서버 이미지 검증에 걸릴 수 있다. image_picker는 대부분 jpg를 돌려준다.
  static DioMediaType _imageMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return DioMediaType('image', 'png');
    if (lower.endsWith('.webp')) return DioMediaType('image', 'webp');
    if (lower.endsWith('.heic')) return DioMediaType('image', 'heic');
    return DioMediaType('image', 'jpeg');
  }
}

/// 인증 API Provider — 다른 repository seam([repository_providers.dart])과 같은
/// 패턴이지만, 병렬 작업 충돌을 피해 이 파일에 둔다(KAN-58).
final verificationRepositoryProvider = Provider<VerificationRepository>(
  (ref) => DioVerificationRepository(ref.watch(dioProvider)),
);
