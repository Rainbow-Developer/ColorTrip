import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// 사진을 어디서 고를지 — image_picker의 `ImageSource`를 화면에 노출하지 않기 위한 래핑.
enum PhotoSource { camera, gallery }

/// 사용자가 고른 사진 1장.
class PickedPhotoFile {
  const PickedPhotoFile({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;

  /// 판정 API가 이미지 형식을 판별하는 데 쓴다(`/verifications/photo` multipart).
  final String filename;
  final String mimeType;
}

/// 사진 선택 실패 — 권한 거부·읽기 실패처럼 사용자에게 안내가 필요한 경우.
class PhotoPickFailure implements Exception {
  const PhotoPickFailure(this.message);

  final String message;
}

/// 갤러리·카메라 사진 선택 seam — [LocationGateway]와 같은 이유로 플러그인을 직접 부르지
/// 않고 이 인터페이스를 통해 쓴다. 위젯 테스트에서 플랫폼 채널 없이 사진 선택을 대체할 수
/// 있어야 인증 흐름(판정 통과·거절)을 검증할 수 있다.
abstract class PhotoPickerGateway {
  /// 사진 선택 — 사용자가 취소하면 null, 실패하면 [PhotoPickFailure].
  Future<PickedPhotoFile?> pick(PhotoSource source);
}

class ImagePickerPhotoPickerGateway implements PhotoPickerGateway {
  const ImagePickerPhotoPickerGateway();

  @override
  Future<PickedPhotoFile?> pick(PhotoSource source) async {
    final XFile? picked;
    try {
      // maxWidth/imageQuality로 대부분의 카메라 사진을 업로드 상한 이하로 미리 줄인다.
      picked = await ImagePicker().pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
    } on Object {
      throw const PhotoPickFailure('사진을 불러오지 못했어요. 카메라·사진 접근 권한을 확인해주세요.');
    }
    if (picked == null) return null; // 사용자가 선택을 취소함 — 에러 아님.

    final Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } on Object {
      throw const PhotoPickFailure('사진을 불러오지 못했어요. 다시 시도해주세요.');
    }
    return PickedPhotoFile(
      bytes: bytes,
      filename: picked.name,
      mimeType: picked.mimeType ?? mimeTypeForName(picked.name),
    );
  }
}

/// 파일명 확장자로 이미지 MIME 타입을 정한다 — 미지정 시 octet-stream으로 가서 서버
/// 이미지 검증에 걸릴 수 있다. image_picker는 대부분 mimeType을 비워 돌려준다.
String mimeTypeForName(String name) {
  final extension = name.split('.').last.toLowerCase();
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    _ => 'image/jpeg',
  };
}
