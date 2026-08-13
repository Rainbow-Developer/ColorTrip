import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/location/location_gateway.dart';
import '../../data/models/quest.dart';
import '../../state/domain_controller.dart';
import '../../state/repository_providers.dart';

/// 퀘스트 수행(인증) 화면 — 여행 시작하기로 담은 퀘스트를 지역 개요("여행하기")의
/// "내 여행 퀘스트" 목록에서 탭하면 여기로 온다(2026-07-09 사용자 확정 — 퀘스트 상세에는
/// 더 이상 수행 버튼이 없다). 사진/GPS/OX퀴즈 유형별 UI는 Figma 스펙(2026-07-08 공유) 반영.
/// 사진은 실제 업로드하고 GPS는 현재 위치를 조회해 서버 검증을 수행한다.
class QuestVerifyScreen extends ConsumerWidget {
  const QuestVerifyScreen({super.key, required this.questId, this.journeyId});

  final String questId;
  final String? journeyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quest = ref.watch(questRepositoryProvider).byId(questId);
    if (quest == null) {
      return const Scaffold(body: Center(child: Text('퀘스트를 찾을 수 없어요')));
    }

    // 이 퀘스트를 담은 그 지역 여행을 찾아 인증을 여정에 연결한다. 진행중 여행을 먼저 보되,
    // 없으면 완료된 여행도 쓴다 — 여행 기간이 지나 완료로 넘어간 뒤에 남은 퀘스트를 인증하면
    // (KAN-73 완료 판정) 진행중 여행이 없어 여정 연결이 끊기고, 지도 채색 집계에도 빠진다.
    final candidates =
        ref
            .watch(domainControllerProvider)
            .value
            ?.journeys
            .where(
              (journey) =>
                  journey.regionKey == quest.region &&
                  journey.questKeys.contains(quest.id),
            )
            .toList() ??
        const [];
    final journeyId =
        this.journeyId ??
        (candidates
                    .where((journey) => journey.status == 'in_progress')
                    .firstOrNull ??
                candidates.firstOrNull)
            ?.id;

    switch (quest.verify) {
      case 'gps':
        return _GpsVerifyBody(
          questTitle: quest.title,
          isReady: quest.lat != null && quest.lng != null,
          onVerified: () => _verifyGps(context, ref, quest, journeyId),
        );
      case 'quiz':
        return _QuizVerifyBody(
          quest: quest,
          fallbackLocation: '/region/${quest.region}',
          onVerified: (answer) => _verify(
            context,
            ref,
            quest,
            journeyId: journeyId,
            answer: answer ? 'O' : 'X',
          ),
        );
      case 'qr':
        return _QrVerifyBody(
          fallbackLocation: '/region/${quest.region}',
          onVerified: (payload) => _verify(
            context,
            ref,
            quest,
            journeyId: journeyId,
            qrPayload: payload,
          ),
        );
      default:
        return _PhotoVerifyBody(
          questTitle: quest.title,
          onVerified: (photo) => _verifyPhoto(
            context,
            ref,
            quest,
            photo.bytes,
            photo.mimeType,
            journeyId,
          ),
        );
    }
  }

  Future<bool?> _verify(
    BuildContext context,
    WidgetRef ref,
    Quest quest, {
    String? journeyId,
    double? latitude,
    double? longitude,
    String? photoUrl,
    String? answer,
    String? qrPayload,
  }) async {
    try {
      final result = await ref
          .read(domainControllerProvider.notifier)
          .verifyQuest(
            questKey: quest.id,
            journeyId: journeyId,
            latitude: latitude,
            longitude: longitude,
            photoUrl: photoUrl,
            answer: answer,
            qrPayload: qrPayload,
          );
      if (!context.mounted) return null;
      if (!result.verified) {
        showAppToast(context, result.reason ?? '인증 조건을 확인해주세요.');
      }
      return result.verified;
    } on Object {
      if (context.mounted) {
        showAppToast(context, '인증 결과를 저장하지 못했어요. 다시 시도해주세요.');
      }
      return null;
    }
  }

  Future<void> _verifyGps(
    BuildContext context,
    WidgetRef ref,
    Quest quest,
    String? journeyId,
  ) async {
    try {
      final location = await ref.read(locationGatewayProvider).current();
      if (!context.mounted) return;
      final verified = await _verify(
        context,
        ref,
        quest,
        journeyId: journeyId,
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (verified == true && context.mounted) {
        showAppToast(context, '퀘스트 완료! 지도가 칠해졌어요');
        _leaveVerifyScreen(context, '/region/${quest.region}');
      }
    } on LocationFailure catch (error) {
      if (context.mounted) await _showLocationFailure(context, ref, error);
    } on Object {
      if (context.mounted) {
        showAppToast(context, '현재 위치를 확인하지 못했어요. 다시 시도해주세요.');
      }
    }
  }

  Future<bool> _verifyPhoto(
    BuildContext context,
    WidgetRef ref,
    Quest quest,
    Uint8List photo,
    String mimeType,
    String? journeyId,
  ) async {
    try {
      final result = await ref
          .read(domainControllerProvider.notifier)
          .uploadAndVerifyPhoto(
            questKey: quest.id,
            bytes: photo,
            mimeType: mimeType,
            journeyId: journeyId,
          );
      if (!context.mounted) return false;
      if (result.verified) {
        context.push('/quest/$questId/verify/result');
        return true;
      }
      showAppToast(context, result.reason ?? '사진 인증 조건을 확인해주세요.');
      return false;
    } on Object {
      if (context.mounted) {
        showAppToast(context, '사진을 업로드하지 못했어요. 다시 시도해주세요.');
      }
      return false;
    }
  }

  Future<void> _showLocationFailure(
    BuildContext context,
    WidgetRef ref,
    LocationFailure error,
  ) async {
    final gateway = ref.read(locationGatewayProvider);
    final (message, action) = switch (error.reason) {
      LocationFailureReason.serviceDisabled => (
        '기기의 위치 서비스를 켜주세요.',
        gateway.openLocationSettings,
      ),
      LocationFailureReason.permissionDeniedForever => (
        '앱 설정에서 위치 권한을 허용해주세요.',
        gateway.openAppSettings,
      ),
      LocationFailureReason.permissionDenied => (
        '위치 권한이 있어야 GPS 인증을 진행할 수 있어요.',
        null,
      ),
      LocationFailureReason.timeout => (
        '현재 위치 확인 시간이 초과됐어요. 실외에서 다시 시도해주세요.',
        null,
      ),
      LocationFailureReason.unavailable => (
        '현재 위치를 확인하지 못했어요. 다시 시도해주세요.',
        null,
      ),
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('위치 확인 필요'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('확인'),
          ),
          if (action != null)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                action();
              },
              child: const Text('설정 열기'),
            ),
        ],
      ),
    );
  }
}

/// 인증 성공 후 인증 화면을 닫고 들어왔던 화면(지역 개요 등)으로 돌아간다.
///
/// `context.go`로 목적지를 지정하면 라우터 스택이 교체돼 뒤로가기가 동작하지 않고 엉뚱한
/// 화면에 남았다(KAN-73 사용자 피드백). 스택이 비어 있는 경우(딥링크 등 직접 진입)에만
/// [fallbackLocation]으로 이동한다.
void _leaveVerifyScreen(BuildContext context, String fallbackLocation) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallbackLocation);
  }
}

class _QuizVerifyBody extends StatefulWidget {
  const _QuizVerifyBody({
    required this.quest,
    required this.onVerified,
    required this.fallbackLocation,
  });

  final Quest quest;
  final Future<bool?> Function(bool answer) onVerified;

  /// 돌아갈 화면이 스택에 없을 때만 쓰는 목적지.
  final String fallbackLocation;

  @override
  State<_QuizVerifyBody> createState() => _QuizVerifyBodyState();
}

class _QuizVerifyBodyState extends State<_QuizVerifyBody> {
  bool? _wrong;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('OX 퀴즈'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.quest.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                widget.quest.quizQuestion ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_wrong == true) ...[
              const SizedBox(height: 8),
              const Text(
                '다시 생각해보세요.',
                style: TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => _answer(true),
                    child: const Text('O'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => _answer(false),
                    child: const Text('X'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _answer(bool value) async {
    setState(() {
      _busy = true;
      _wrong = false;
    });
    final verified = await widget.onVerified(value);
    if (!mounted) return;
    if (verified == true) {
      showAppToast(context, '퀘스트 완료! 지도가 칠해졌어요');
      _leaveVerifyScreen(context, widget.fallbackLocation);
      return;
    }
    if (verified == null) {
      setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = false;
      _wrong = true;
    });
  }
}

class _GpsVerifyBody extends StatefulWidget {
  const _GpsVerifyBody({
    required this.questTitle,
    required this.isReady,
    required this.onVerified,
  });

  final String questTitle;
  final bool isReady;
  final Future<void> Function() onVerified;

  @override
  State<_GpsVerifyBody> createState() => _GpsVerifyBodyState();
}

class _GpsVerifyBodyState extends State<_GpsVerifyBody> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('GPS 인증'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.questTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              '퀘스트에 설정된 인증 반경 안에서 시도해주세요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.verifyMapBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryDark,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text('📍'),
                    ),
                  ),
                  const Positioned(
                    left: 12,
                    top: 10,
                    child: Text(
                      '지도 미리보기',
                      style: TextStyle(color: AppColors.formPlaceholder),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.timelineLine),
                      ),
                      child: const Text(
                        '현재 위치',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (!widget.isReady)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  '이 퀘스트는 위치 정보가 준비되지 않았어요.',
                  style: TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '현재 위치',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const Text(
                        '인증 버튼을 누르면 확인해요',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ℹ️ GPS 정확도에 따라 인증이 지연될 수 있습니다. 실외에서 시도해주세요.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _busy || !widget.isReady
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await widget.onVerified();
                      if (mounted) setState(() => _busy = false);
                    },
              child: Text(_busy ? '현재 위치 확인 중...' : '현재 위치로 인증하기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrVerifyBody extends StatefulWidget {
  const _QrVerifyBody({
    required this.onVerified,
    required this.fallbackLocation,
  });

  final Future<bool?> Function(String payload) onVerified;

  /// 돌아갈 화면이 스택에 없을 때만 쓰는 목적지.
  final String fallbackLocation;

  @override
  State<_QrVerifyBody> createState() => _QrVerifyBodyState();
}

class _QrVerifyBodyState extends State<_QrVerifyBody> {
  bool _busy = false;

  Future<void> _verify(BarcodeCapture capture) async {
    if (_busy) return;
    final payload = capture.barcodes.firstOrNull?.rawValue;
    if (payload == null || payload.isEmpty) return;
    setState(() => _busy = true);
    final verified = await widget.onVerified(payload);
    if (!mounted) return;
    if (verified == true) {
      showAppToast(context, '퀘스트 완료! 지도가 칠해졌어요');
      _leaveVerifyScreen(context, widget.fallbackLocation);
      return;
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('QR 인증'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('현장에 부착된 QR 코드를 프레임 안에 맞춰주세요.'),
            const SizedBox(height: 16),
            Expanded(
              child: MobileScanner(
                onDetect: _verify,
                errorBuilder: (_, _) => const Center(
                  child: Text(
                    '카메라를 열 수 없어요. 기기 권한을 확인한 뒤 다시 시도해주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoVerifyBody extends StatefulWidget {
  const _PhotoVerifyBody({required this.questTitle, required this.onVerified});

  final String questTitle;

  /// 완료 처리 콜백 — 사용자가 실제로 고른 사진을 함께 넘겨 히스토리에 남긴다.
  final Future<bool> Function(_PickedPhoto photo) onVerified;

  @override
  State<_PhotoVerifyBody> createState() => _PhotoVerifyBodyState();
}

class _PhotoVerifyBodyState extends State<_PhotoVerifyBody> {
  // "업로드 가이드"에 안내한 상한과 맞춘다.
  static const _maxPhotoBytes = 5 * 1024 * 1024;

  Uint8List? _photoBytes;
  String _photoMimeType = 'image/jpeg';
  bool _busy = false;

  Future<void> _pickPhoto(ImageSource source) async {
    final XFile? picked;
    try {
      // maxWidth/imageQuality로 대부분의 카메라 사진을 5MB 이하로 미리 줄인다.
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, '사진을 불러오지 못했어요. 카메라·사진 접근 권한을 확인해주세요.');
      return;
    }
    final selected = picked;
    if (selected == null) return; // 사용자가 선택을 취소함 — 에러 아님.

    final Uint8List bytes;
    try {
      bytes = await selected.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, '사진을 불러오지 못했어요. 다시 시도해주세요.');
      return;
    }
    if (bytes.length > _maxPhotoBytes) {
      if (!mounted) return;
      showAppToast(context, '사진 용량은 5MB 이하만 가능해요.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoMimeType = selected.mimeType ?? _mimeTypeForName(selected.name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final photoBytes = _photoBytes;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('사진 인증'),
      ),
      // 업로드 + AI 판정을 기다리는 동안 화면 전체를 스크림으로 덮는다 — 버튼만 비활성화하면
      // 진행 중인지 알기 어렵다는 피드백(KAN-73).
      body: Stack(
        fit: StackFit.expand,
        children: [
          _form(photoBytes),
          if (_busy) const _VerifyingScrim(message: '사진 확인 중...'),
        ],
      ),
    );
  }

  Widget _form(Uint8List? photoBytes) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.questTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            '퀘스트 장소 사진을 업로드해주세요.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => _pickPhoto(ImageSource.gallery),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 120,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.uploadBoxBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: photoBytes != null
                      ? AppColors.primaryDark
                      : AppColors.uploadBoxBorder,
                ),
              ),
              alignment: Alignment.center,
              child: photoBytes != null
                  ? Image.memory(
                      photoBytes,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('📷', style: TextStyle(fontSize: 28)),
                        SizedBox(height: 4),
                        Text(
                          '사진 촬영 또는 갤러리 선택',
                          style: TextStyle(
                            color: AppColors.formPlaceholder,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PhotoSourceButton(
                  label: '📷 카메라',
                  onTap: () => _pickPhoto(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PhotoSourceButton(
                  label: '🖼 갤러리',
                  onTap: () => _pickPhoto(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '업로드 가이드',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                SizedBox(height: 6),
                Text(
                  '• 퀘스트 장소가 잘 보이는 사진\n• 최근 24시간 이내 촬영\n• 5MB 이하 JPG/PNG',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: photoBytes != null && !_busy
                ? () async {
                    setState(() => _busy = true);
                    await widget.onVerified(
                      _PickedPhoto(photoBytes, _photoMimeType),
                    );
                    if (mounted) setState(() => _busy = false);
                  }
                : null,
            child: Text(
              _busy
                  ? '사진 확인 중...'
                  : photoBytes != null
                  ? '사진으로 인증하기'
                  : '사진 선택 후 인증 가능',
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedPhoto {
  const _PickedPhoto(this.bytes, this.mimeType);

  final Uint8List bytes;
  final String mimeType;
}

/// 인증 진행 중 화면을 덮는 스크림 + 진행 카드(KAN-73).
///
/// 라우트(다이얼로그)가 아니라 화면 안의 레이어다 — 인증 성공 시 결과 화면을 push 하는데,
/// 다이얼로그였다면 그 위에 남거나 pop 순서가 엉킬 수 있다.
class _VerifyingScrim extends StatelessWidget {
  const _VerifyingScrim({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: ColoredBox(
        color: AppColors.verifyScrim,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '잠시만 기다려주세요',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _mimeTypeForName(String name) {
  final extension = name.split('.').last.toLowerCase();
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    _ => 'image/jpeg',
  };
}

class _PhotoSourceButton extends StatelessWidget {
  const _PhotoSourceButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ),
    );
  }
}
