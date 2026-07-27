import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/static/regions_data.dart';
import '../../state/progress_notifier.dart';
import '../../state/auth_controller.dart';
import '../../state/repository_providers.dart';

/// 공유 카드 만들기 — Figma 스펙(2026-07-08 공유) 반영. 이미지 저장·링크 복사·공유는
/// 실제 내보내기 없이 토스트로 흉내만 낸다(실 구현은 후속 작업, [implementation.md] 참고).
class ShareCardScreen extends ConsumerStatefulWidget {
  const ShareCardScreen({super.key});

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

enum _ShareStyle { mapAndDna, mapOnly, dnaOnly }

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> {
  _ShareStyle _style = _ShareStyle.mapAndDna;

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
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
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
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.shareMapPreviewBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '지도 미리보기',
                        style: TextStyle(color: AppColors.shareMapPreviewText),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ShareStat(
                        label: '완료 지역',
                        value: '${progress.completedRegionCount}',
                      ),
                      _ShareStat(label: '진행률', value: '$progressPct%'),
                      _ShareStat(
                        label: dna.name.replaceAll(' 여행자', ''),
                        value: dna.icon,
                      ),
                    ],
                  ),
                ],
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
                    label: '지도 +\nDNA',
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
                  child: OutlinedButton(
                    onPressed: () => showAppToast(context, '이미지가 저장되었어요'),
                    child: const Text('📸 이미지 저장'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showAppToast(context, '링크가 복사되었어요'),
                    child: const Text('🔗 링크 복사'),
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => showAppToast(context, '공유했어요'),
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
