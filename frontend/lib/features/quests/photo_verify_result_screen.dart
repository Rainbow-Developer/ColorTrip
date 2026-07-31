import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../data/models/verification.dart';
import '../../state/progress_notifier.dart';
import '../../state/repository_providers.dart';

/// 사진 검증 결과 — 인증 화면이 라우트 extra로 넘긴 **실제 AI 판정값**
/// (통과 여부·신뢰도·사유·판정 제공자)을 표시한다(docs/specs/050-quest-verification).
/// 판정 제공자가 stub이면 "AI 미설정(스텁 판정)" 뱃지를 함께 띄운다.
class PhotoVerifyResultScreen extends ConsumerWidget {
  const PhotoVerifyResultScreen({
    super.key,
    required this.questId,
    this.verdict,
  });

  final String questId;

  /// 인증 화면(`quest_verify_screen`)이 넘긴 판정값 — 통과 시에만 이 화면으로
  /// 오지만, 직접 URL 진입 등으로 없을 수 있어 nullable로 방어한다.
  final PhotoVerdict? verdict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quest = ref.watch(questRepositoryProvider).byId(questId);
    if (quest == null) {
      return const Scaffold(body: Center(child: Text('퀘스트를 찾을 수 없어요')));
    }
    final region = ref.watch(regionRepositoryProvider).byId(quest.region);
    // 통과했을 때만 이 화면으로 push되지만, 거절 판정이 실수로 넘어와도 화면이
    // 거짓말하지 않도록 passed를 기준으로 렌더링한다. 판정값이 없는 경우(직접 URL
    // 진입 등)는 임의로 성공으로 단정하지 않고 실제 완료 여부를 근거로 삼는다.
    final passed =
        verdict?.passed ?? ref.watch(progressProvider).isCompleted(questId);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('사진 검증 결과'),
        titleSpacing: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: passed
                        ? AppColors.tripActiveBadgeBg
                        : AppColors.tripMutedBadgeBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    passed ? '✅' : '❌',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  passed ? '인증 성공!' : '인증이 거절되었어요',
                  style: TextStyle(
                    color: passed
                        ? AppColors.tripActiveBadgeFg
                        : AppColors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  passed
                      ? '${quest.place} 방문이 확인되었습니다.'
                      : '${quest.place} 방문을 확인하지 못했습니다.',
                  style: const TextStyle(
                    color: AppColors.tripMutedBadgeFg,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildVerdictCard(),
            if (passed) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.tripActiveBadgeBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Text(
                      '퀘스트 완료!',
                      style: TextStyle(
                        color: AppColors.tripActiveBadgeFg,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${region?.name ?? quest.region} 지도가 색칠되었습니다 🎉',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('지도에서 확인하기'),
            ),
          ],
        ),
      ),
    );
  }

  /// AI 판정 상세 카드 — 신뢰도(%)·판정 결과·사유. 스텁 판정이면 뱃지 표시.
  Widget _buildVerdictCard() {
    final v = verdict;
    return Container(
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
                'AI 검증 결과',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              if (v != null && v.isStub)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tripMutedBadgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AI 미설정(스텁 판정)',
                    style: TextStyle(
                      color: AppColors.tripMutedBadgeFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (v == null)
            const Text(
              '판정 정보를 불러오지 못했어요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          else ...[
            _ResultRow(label: '판정 결과', value: v.passed ? '통과' : '거절'),
            const SizedBox(height: 10),
            _ResultRow(label: '신뢰도', value: '${(v.confidence * 100).round()}%'),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: v.confidence.clamp(0, 1).toDouble(),
                minHeight: 4,
                backgroundColor: AppColors.verifyProgressTrack,
                valueColor: const AlwaysStoppedAnimation(AppColors.primaryDark),
              ),
            ),
            if (v.reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                '판정 사유',
                style: TextStyle(
                  color: AppColors.tripMutedBadgeFg,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                v.reason,
                style: const TextStyle(
                  color: AppColors.textBody,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.tripMutedBadgeFg,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
