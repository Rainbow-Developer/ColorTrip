import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../state/repository_providers.dart';

/// 사진 검증 결과 — Figma 스펙(2026-07-09 공유) 반영. AI 검증 지표(장소 일치도·사진 진위·촬영 시간)는
/// 실제 분석 없이 고정값으로 보여주는 최소 버전이다([implementation.md] 참고).
class PhotoVerifyResultScreen extends ConsumerWidget {
  const PhotoVerifyResultScreen({super.key, required this.questId});

  final String questId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quest = ref.watch(questRepositoryProvider).byId(questId);
    if (quest == null) {
      return const Scaffold(body: Center(child: Text('퀘스트를 찾을 수 없어요')));
    }
    final region = ref.watch(regionRepositoryProvider).byId(quest.region);

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
                  decoration: const BoxDecoration(
                    color: AppColors.tripActiveBadgeBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('✅', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(height: 8),
                const Text(
                  '인증 성공!',
                  style: TextStyle(
                    color: AppColors.tripActiveBadgeFg,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${quest.place} 방문이 확인되었습니다.',
                  style: const TextStyle(
                    color: AppColors.tripMutedBadgeFg,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI 검증 결과',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  const _ResultRow(label: '장소 일치도', value: '94%'),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: 0.94,
                      minHeight: 4,
                      backgroundColor: AppColors.verifyProgressTrack,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _ResultRow(label: '사진 진위 여부', value: '통과'),
                  const SizedBox(height: 6),
                  const _ResultRow(label: '촬영 시간', value: '24시간 이내'),
                ],
              ),
            ),
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
