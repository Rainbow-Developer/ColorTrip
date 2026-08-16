import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/chungbuk_map.dart';
import '../../data/static/regions_data.dart';
import '../../state/progress_notifier.dart';
import '../../state/auth_controller.dart';
import '../../state/repository_providers.dart';

/// 공유 카드 만들기 — Figma 스펙(2026-07-08 공유) 반영. 이미지 저장은 미리보기 카드를
/// [RepaintBoundary]로 캡처해 `gal` 패키지로 갤러리에 저장한다(KAN-072). 공유·링크 복사는
/// 실제 `POST /shares`로 링크를 발급받아 안드로이드 네이티브 공유 시트·클립보드에 사용한다
/// ([060-share-native-experience]).
class ShareCardScreen extends ConsumerStatefulWidget {
  const ShareCardScreen({super.key});

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

enum _ShareStyle { mapAndDna, mapOnly, dnaOnly }

extension on _ShareStyle {
  /// 백엔드 `ShareStyle` Enum 값과 일치시킨다([030-share-card] `shares/schemas.py`).
  String get apiValue => switch (this) {
    _ShareStyle.mapAndDna => 'MAP_AND_DNA',
    _ShareStyle.mapOnly => 'MAP',
    _ShareStyle.dnaOnly => 'DNA',
  };
}

typedef ShareImageSaver =
    Future<void> Function(Uint8List bytes, {required String name});

final shareImageSaverProvider = Provider<ShareImageSaver>(
  (ref) =>
      (bytes, {required name}) => Gal.putImageBytes(bytes, name: name),
);

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> {
  final _previewKey = GlobalKey();
  _ShareStyle _style = _ShareStyle.mapAndDna;
  bool _isLinking = false;
  bool _isSaving = false;

  Future<void> _saveImage() async {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    setState(() => _isSaving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _previewKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Share preview is not ready.');
      }
      // 기기 배율(devicePixelRatio)로 캡처해야 저장된 이미지가 흐릿하지 않다.
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData;
      try {
        byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        image.dispose();
      }
      if (byteData == null) {
        throw StateError('Could not encode the share preview.');
      }
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      await ref.read(shareImageSaverProvider)(
        bytes,
        name: 'colortrip_share_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      showAppToast(context, '이미지가 저장되었어요');
    } on GalException catch (error) {
      if (!mounted) return;
      final message = switch (error.type) {
        GalExceptionType.accessDenied => '이미지 저장 권한이 필요해요. 설정에서 허용해주세요.',
        GalExceptionType.notEnoughSpace => '저장 공간이 부족해요.',
        GalExceptionType.notSupportedFormat ||
        GalExceptionType.unexpected => '이미지 저장에 실패했어요. 다시 시도해주세요.',
      };
      showAppToast(context, message);
    } catch (_) {
      if (mounted) showAppToast(context, '이미지 저장에 실패했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _createShareLink() async {
    setState(() => _isLinking = true);
    try {
      return await ref
          .read(shareRepositoryProvider)
          .createShareLink(_style.apiValue);
    } catch (_) {
      if (mounted) {
        showAppToast(context, '공유 링크 생성에 실패했어요. 다시 시도해주세요.');
      }
      return null;
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  Future<void> _copyLink() async {
    final url = await _createShareLink();
    if (url == null || !mounted) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    showAppToast(context, '링크가 복사되었어요');
  }

  Future<void> _shareViaSheet() async {
    final url = await _createShareLink();
    if (url == null) return;
    final user = ref.read(currentUserProvider);
    final who = user?.nickname == null ? '내' : '${user!.nickname}님의';
    await SharePlus.instance.share(
      ShareParams(text: '$who 다채로울지도 여행 지도를 확인해보세요! $url'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final user = ref.watch(currentUserProvider);
    final dna = ref
        .watch(dnaRepositoryProvider)
        .byId(user?.dna ?? progress.dnaType ?? 'nature');
    final progressPct = (progress.completedRegionCount / kRegions.length * 100)
        .round();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('공유 카드 만들기'),
        titleSpacing: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepaintBoundary(
              key: _previewKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.tripActiveBadgeBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      user?.nickname == null
                          ? '나의 여행 지도'
                          : '${user!.nickname}님의 여행 지도',
                      style: TextStyle(
                        color: AppColors.tripActiveBadgeFg,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_style != _ShareStyle.dnaOnly)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.shareMapPreviewBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ChungbukMap(
                          regionSaturation: {
                            for (final region in kRegions)
                              region.id: progress.regionSaturation(region.id),
                          },
                        ),
                      ),
                    if (_style != _ShareStyle.dnaOnly)
                      const SizedBox(height: 12),
                    if (_style != _ShareStyle.dnaOnly)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ShareStat(
                            label: '여행 완료',
                            value: '${progress.completedJourneyCount}',
                          ),
                          _ShareStat(label: '채색률', value: '$progressPct%'),
                        ],
                      ),
                    if (_style != _ShareStyle.mapOnly) ...[
                      if (_style != _ShareStyle.dnaOnly)
                        const SizedBox(height: 14),
                      Text(
                        dna.name,
                        style: const TextStyle(
                          color: AppColors.tripActiveBadgeFg,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dna.desc,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '공유 스타일 선택',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StyleOption(
                    label: '지도 + DNA',
                    selected: _style == _ShareStyle.mapAndDna,
                    onTap: () => setState(() => _style = _ShareStyle.mapAndDna),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StyleOption(
                    label: '지도만',
                    selected: _style == _ShareStyle.mapOnly,
                    onTap: () => setState(() => _style = _ShareStyle.mapOnly),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StyleOption(
                    label: 'DNA만',
                    selected: _style == _ShareStyle.dnaOnly,
                    onTap: () => setState(() => _style = _ShareStyle.dnaOnly),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _saveImage,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('이미지 저장'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLinking ? null : _copyLink,
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('링크 복사'),
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isLinking ? null : _shareViaSheet,
              child: const Text('공유'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareStat extends StatelessWidget {
  const _ShareStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.tripActiveBadgeFg,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StyleOption extends StatelessWidget {
  const _StyleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: selected
                ? AppColors.primaryDark
                : AppColors.tripMutedBadgeFg,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
