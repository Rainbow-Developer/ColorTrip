import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../data/models/quest.dart';
import '../../state/progress_notifier.dart';
import '../../state/repository_providers.dart';

/// 여행하기 — 지도에서 지역을 탭하면 처음 보는 화면. Figma 스펙(2026-07-09 공유) 반영:
/// 지역 이미지 placeholder, DNA 요약 카드, 추천 퀘스트 2건(정보만, 수행 버튼 없음),
/// "퀘스트 선택하기" → 퀘스트 선택 화면. 여행이 이미 시작된 지역이면 대신 "내 여행 퀘스트"
/// 목록을 보여준다(2026-07-09 사용자 확정 — 퀘스트 선택은 다중 선택이며, 그 자리에서 수행하지 않는다).
class RegionOverviewScreen extends ConsumerWidget {
  const RegionOverviewScreen({super.key, required this.regionId});

  final String regionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final region = ref.watch(regionRepositoryProvider).byId(regionId);
    final questRepo = ref.watch(questRepositoryProvider);
    final regionQuests = questRepo.byRegion(regionId);
    final progress = ref.watch(progressProvider);
    final dnaType = progress.dnaType ?? 'nature';
    final dna = ref.watch(dnaRepositoryProvider).byId(dnaType);
    final tripQuests = progress.tripQuestsOf(regionId);
    final tripStarted = tripQuests.isNotEmpty;

    final recommended = <Quest>[
      ...regionQuests.where((q) => q.type == dnaType).take(2),
    ];
    if (recommended.length < 2) {
      recommended.addAll(
        regionQuests
            .where((q) => !recommended.contains(q))
            .take(2 - recommended.length),
      );
    }

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text('여행하기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.imagePlaceholderBg,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                '${region.name} 이미지',
                style: const TextStyle(color: AppColors.formPlaceholder),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.tripActiveBadgeBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(dna.icon, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 6),
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final tag in dna.tags.take(3))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              color: AppColors.tripActiveBadgeFg,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (tripStarted) ...[
              const Text(
                '내 여행 퀘스트',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              for (final questId in tripQuests)
                if (questRepo.byId(questId) case final quest?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TripQuestTile(
                      quest: quest,
                      regionName: region.name,
                      done: progress.isCompleted(quest.id),
                      onTap: () => progress.isCompleted(quest.id)
                          ? context.push('/quest/${quest.id}')
                          : context.push('/quest/${quest.id}/verify'),
                    ),
                  ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/region/$regionId/quests'),
                child: const Text('퀘스트 더 선택하기'),
              ),
            ] else ...[
              const Text(
                '추천 퀘스트',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              for (final quest in recommended)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecommendedQuestTile(
                    quest: quest,
                    regionName: region.name,
                    onTap: () => context.push('/quest/${quest.id}'),
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.push('/region/$regionId/quests'),
                child: const Text('퀘스트 선택하기'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripQuestTile extends StatelessWidget {
  const _TripQuestTile({
    required this.quest,
    required this.regionName,
    required this.done,
    required this.onTap,
  });

  final Quest quest;
  final String regionName;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.imagePlaceholderBg,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _MiniBadge(
                        label: regionName,
                        background: AppColors.tripActiveBadgeBg,
                        foreground: AppColors.tripActiveBadgeFg,
                      ),
                      const SizedBox(width: 4),
                      _MiniBadge(
                        label: questTypeStyles[quest.type]?.label ?? quest.type,
                        background: AppColors.tripMutedBadgeBg,
                        foreground: AppColors.tripMutedBadgeFg,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              done ? Icons.check_circle : Icons.chevron_right,
              color: done ? AppColors.primaryDark : AppColors.timelineDotGrey,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedQuestTile extends StatelessWidget {
  const _RecommendedQuestTile({
    required this.quest,
    required this.regionName,
    required this.onTap,
  });

  final Quest quest;
  final String regionName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.imagePlaceholderBg,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _MiniBadge(
                        label: regionName,
                        background: AppColors.tripActiveBadgeBg,
                        foreground: AppColors.tripActiveBadgeFg,
                      ),
                      const SizedBox(width: 4),
                      _MiniBadge(
                        label: questTypeStyles[quest.type]?.label ?? quest.type,
                        background: AppColors.tripMutedBadgeBg,
                        foreground: AppColors.tripMutedBadgeFg,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: foreground)),
    );
  }
}
