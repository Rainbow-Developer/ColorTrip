import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants.dart';
import '../image_picking.dart';
import 'app_network_image.dart';
import 'app_toast.dart';

/// 원형 프로필 이미지 + 탭하면 열리는 카메라/갤러리/제거 바텀시트.
///
/// 회원가입과 내 정보 수정이 함께 쓴다. provider에 의존하지 않고 콜백만 받아서
/// 각 화면이 자기 컨트롤러에 연결한다 (docs/specs/080-profile-image).
class ProfileImagePicker extends StatelessWidget {
  const ProfileImagePicker({
    super.key,
    required this.imageUrl,
    required this.onPicked,
    this.onRemoved,
    this.isBusy = false,
    this.size = 88,
    this.pickImage,
  });

  /// 이미 절대 URL로 해석된 값. null이면 기본 placeholder를 그린다.
  final String? imageUrl;

  final Future<void> Function(PickedImage picked) onPicked;

  /// null이면 '기본 이미지로 변경' 항목을 숨긴다.
  final Future<void> Function()? onRemoved;

  final bool isBusy;
  final double size;

  /// 테스트 seam — 기본값은 실제 플랫폼 피커([pickImageBytes])다.
  final Future<PickedImage?> Function(ImageSource source)? pickImage;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '프로필 이미지 선택',
      child: InkWell(
        onTap: isBusy ? null : () => _openSourceSheet(context),
        customBorder: const CircleBorder(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AppNetworkImage(
              url: imageUrl,
              width: size,
              height: size,
              borderRadius: BorderRadius.circular(size / 2),
              placeholderEmoji: '👤',
              placeholderEmojiSize: size * 0.34,
            ),
            if (isBusy)
              SizedBox(
                width: size,
                height: size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(size / 2),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: size * 0.16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSourceSheet(BuildContext context) async {
    final action = await showModalBottomSheet<_PickerAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.of(sheetContext).pop(_PickerAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_PickerAction.gallery),
            ),
            if (onRemoved != null && imageUrl != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                ),
                title: const Text(
                  '기본 이미지로 변경',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PickerAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    if (action == _PickerAction.remove) {
      await onRemoved?.call();
      return;
    }

    final source = action == _PickerAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    final pick = pickImage ?? pickImageBytes;
    final PickedImage? picked;
    try {
      picked = await pick(source);
    } on PickImageException catch (error) {
      if (!context.mounted) return;
      showAppToast(context, switch (error.reason) {
        PickImageFailure.permission => '사진을 불러오지 못했어요. 카메라·사진 접근 권한을 확인해주세요.',
        PickImageFailure.read => '사진을 불러오지 못했어요. 다시 시도해주세요.',
        PickImageFailure.tooLarge => '사진 용량은 5MB 이하만 가능해요.',
      });
      return;
    }
    if (picked == null) return; // 사용자가 선택을 취소함 — 에러 아님.

    await onPicked(picked);
  }
}

enum _PickerAction { camera, gallery, remove }
