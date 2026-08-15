/// 이미지 피킹 공용 로직 — 퀘스트 사진 인증과 프로필 이미지가 함께 쓴다.
///
/// UI를 포함하지 않는 순수 로직이라 호출부가 각자의 안내 문구·레이아웃을 유지할 수 있고,
/// 플랫폼 채널 없이 주입 seam으로 테스트할 수 있다 (docs/specs/080-profile-image).
library;

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// 서버 상한(`MAX_UPLOAD_SIZE_MB`, 기본 10MB)보다 낮게 잡은 클라이언트 상한.
/// "업로드 가이드"에 안내한 값과 맞춘다.
const int kMaxPickedImageBytes = 5 * 1024 * 1024;

class PickedImage {
  const PickedImage(this.bytes, this.mimeType);

  final Uint8List bytes;
  final String mimeType;
}

enum PickImageFailure {
  /// 피커를 열지 못했다 — 대부분 카메라·사진 접근 권한 문제다.
  permission,

  /// 파일을 읽지 못했다.
  read,

  /// [kMaxPickedImageBytes]를 넘었다.
  tooLarge,
}

class PickImageException implements Exception {
  const PickImageException(this.reason);

  final PickImageFailure reason;
}

/// 이미지를 고르고 바이트로 읽는다. 사용자가 취소하면 `null`을 반환한다(에러 아님).
///
/// 실패는 [PickImageException]으로 던져 호출부가 화면에 맞는 문구를 고르게 한다.
Future<PickedImage?> pickImageBytes(ImageSource source) async {
  final XFile? picked;
  try {
    // maxWidth/imageQuality로 대부분의 카메라 사진을 상한 이하로 미리 줄인다.
    picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 85,
    );
  } catch (_) {
    throw const PickImageException(PickImageFailure.permission);
  }
  final selected = picked;
  if (selected == null) return null;

  final Uint8List bytes;
  try {
    bytes = await selected.readAsBytes();
  } catch (_) {
    throw const PickImageException(PickImageFailure.read);
  }
  if (bytes.length > kMaxPickedImageBytes) {
    throw const PickImageException(PickImageFailure.tooLarge);
  }

  return PickedImage(
    bytes,
    selected.mimeType ?? mimeTypeForFileName(selected.name),
  );
}

/// 확장자로 MIME 타입을 판별한다. 서버 허용 목록(jpeg/png/webp/heic)에 맞춘다.
/// content type을 비워 보내면 서버가 `octet-stream`으로 보고 거부한다.
String mimeTypeForFileName(String name) {
  final extension = name.split('.').last.toLowerCase();
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    _ => 'image/jpeg',
  };
}
