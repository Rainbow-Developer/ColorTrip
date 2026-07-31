import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/chungbuk_map.dart';
import '../../core/widgets/coach_mark.dart';
import '../../core/widgets/map_legend.dart';
import '../../data/models/region.dart';
import '../../data/repositories/quest_repository.dart';
import '../../data/repositories/region_repository.dart';
import '../../data/static/regions_data.dart';
import '../../state/map_sync_provider.dart';
import '../../state/onboarding_tour_notifier.dart';
import '../../state/progress_notifier.dart';
import '../../state/progress_state.dart';
import '../../state/repository_providers.dart';

/// 홈 화면에 하나만 존재하므로 모듈 전역 키로 충분하다(코치마크가 지도 위치를 측정하는 용도).
final _mapKey = GlobalKey();

/// 홈(지도) — Figma 스펙(2026-07-08 공유) 반영: 완료 지역/진행률 스탯, 추천 여행지 배너(KAN-28),
/// 진행중 여행+DNA 카드, 지도 색칠(범례 포함), 최근 완료 섹션. 공유 버튼은 지도 바로 위에 붙여
/// 무엇을 공유하는지 헷갈리지 않게 한다(2026-07-11 KAN-029). 온보딩 투어 1단계로 지도를
/// 코치마크로 안내한다(KAN-040 피드백 — 텍스트 설명 대신 실제 화면에 화살표로 표시).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 진입 시 서버 지도 진행도를 1회 동기화한다(로그인 전이면 조용히 무시, [020-frontend-map-sync]).
    ref.watch(mapSyncProvider);
    final progress = ref.watch(progressProvider);
    final progressPct = (progress.completedRegionCount / kRegions.length * 100)
        .round();
    final tour = ref.watch(onboardingTourProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('다채로울지도')),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatsSummaryCard(
                    completedRegionCount: progress.completedRegionCount,
                    totalRegionCount: kRegions.length,
                    progressPct: progressPct,
                  ),
                  const SizedBox(height: 16),
                  const _InProgressDnaCard(),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => context.push('/share'),
                      icon: const Icon(Icons.ios_share, size: 16),
                      label: const Text('공유하기'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  KeyedSubtree(
                    key: _mapKey,
                    child: ChungbukMap(
                      regionSaturation: {
                        for (final region in kRegions)
                          region.id: progress.regionSaturation(region.id),
                      },
                      onRegionTap: (regionId) =>
                          context.push('/region/$regionId'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const MapLegend(),
                  const SizedBox(height: 20),
                  const _RecommendedRegionBanner(),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '최근 완료',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/timeline'),
                        child: const Text(
                          '더보기 ›',
                          style: TextStyle(color: AppColors.timelineDateText),
                        ),
                      ),
                    ],
                  ),
                  if (progress.timeline.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '아직 완료한 퀘스트가 없어요.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    for (final entry in progress.timeline.take(3))
                      _RecentCompletedTile(
                        entry: entry,
                        questRepo: ref.watch(questRepositoryProvider),
                        regionRepo: ref.watch(regionRepositoryProvider),
                      ),
                ],
              ),
            ),
            if (!tour.isDone && tour.step == 0)
              CoachMarkOverlay(
                targetKey: _mapKey,
                stepIndex: 0,
                title: '지도에서 지역을 눌러보세요',
                body: '가고 싶은 지역을 누르면 추천 퀘스트를 볼 수 있어요.',
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsSummaryCard extends StatelessWidget {
  const _StatsSummaryCard({
    required this.completedRegionCount,
    required this.totalRegionCount,
    required this.progressPct,
  });

  final int completedRegionCount;
  final int totalRegionCount;
  final int progressPct;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  label: '완료한 지역',
                  value: '$completedRegionCount / $totalRegionCount',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatColumn(
                  label: '진행률',
                  value: '$progressPct%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progressPct / 100,
              minHeight: 6,
              backgroundColor: const Color(0xFFEEEEEA),
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.formLabel),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111111),
          ),
        ),
      ],
    );
  }
}

/// 추천 여행지 배너 — 사용자 DNA 유형과 같은 유형 퀘스트가 가장 많은 **여행 시작 전** 지역을
/// 추천한다(동률이면 전체 퀘스트 수가 많은 쪽). 탭하면 지역 개요로 이동해 바로 여행을 시작할 수
/// 있다. 시작 안 한 지역이 없으면 배너를 숨긴다(KAN-28).
class _RecommendedRegionBanner extends ConsumerWidget {
  const _RecommendedRegionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final dnaId = progress.dnaType ?? 'nature';
    final dna = ref.watch(dnaRepositoryProvider).byId(dnaId);
    final questRepo = ref.watch(questRepositoryProvider);

    Region? best;
    var bestMatch = -1;
    var bestTotal = -1;
    for (final region in kRegionsInMapOrder) {
      if (progress.tripStatusOf(region.id) != RegionTripStatus.notStarted) {
        continue;
      }
      final quests = questRepo.byRegion(region.id);
      if (quests.isEmpty) continue;
      final match = quests.where((q) => q.type == dnaId).length;
      if (match > bestMatch ||
          (match == bestMatch && quests.length > bestTotal)) {
        best = region;
        bestMatch = match;
        bestTotal = quests.length;
      }
    }
    if (best == null) return const SizedBox.shrink();

    final region = best;
    final typeLabel = questTypeStyles[dnaId]?.label ?? dnaId;
    final questLabel = bestMatch > 0
        ? '$typeLabel 퀘스트 $bestMatch개가 기다리고 있어요'
        : '퀘스트 $bestTotal개가 기다리고 있어요';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/region/${region.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dna.gradient,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dna.icon} ${dna.name}를 위한 추천 여행지',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      region.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      questLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

/// 진행 중인 지역(0<진행도<전체) + 여행 DNA 요약 카드.
class _InProgressDnaCard extends ConsumerWidget {
  const _InProgressDnaCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final dna = ref
        .watch(dnaRepositoryProvider)
        .byId(progress.dnaType ?? 'nature');

    String? inProgressLabel;
    for (final region in kRegionsInMapOrder) {
      if (progress.tripStatusOf(region.id) != RegionTripStatus.inProgress) {
        continue;
      }
      final trip = progress.tripQuestsOf(region.id);
      final done = trip.where(progress.isCompleted).length;
      inProgressLabel = '${region.name} $done/${trip.length}';
      break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tripActiveBadgeBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          if (inProgressLabel != null) ...[
            Text(
              '진행중인 여행',
              style: const TextStyle(
                color: AppColors.tripActiveBadgeFg,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              inProgressLabel,
              style: const TextStyle(
                color: AppColors.tripActiveBadgeFg,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
          ],
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
    );
  }
}

class _RecentCompletedTile extends StatelessWidget {
  const _RecentCompletedTile({
    required this.entry,
    required this.questRepo,
    required this.regionRepo,
  });

  final TimelineEntry entry;
  final QuestRepository questRepo;
  final RegionRepository regionRepo;

  @override
  Widget build(BuildContext context) {
    final quest = questRepo.byId(entry.questId);
    if (quest == null) return const SizedBox.shrink();
    final region = regionRepo.byId(quest.region);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              questTypeStyles[quest.type]?.emoji ?? '📍',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${region?.name ?? quest.region} · ${entry.date}',
                  style: const TextStyle(
                    color: AppColors.timelineDateText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
