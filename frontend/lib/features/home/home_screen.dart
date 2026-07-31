import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/chungbuk_map.dart';
import '../../core/widgets/coach_mark.dart';
import '../../core/widgets/map_legend.dart';
import '../../data/models/home_recommendation.dart';
import '../../data/models/quest.dart';
import '../../data/models/region.dart';
import '../../data/repositories/quest_repository.dart';
import '../../data/repositories/region_repository.dart';
import '../../data/static/regions_data.dart';
import '../../state/home_recommendation_provider.dart';
import '../../state/auth_controller.dart';
import '../../state/domain_recommendation_providers.dart';
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
    final progress = ref.watch(progressProvider);
    final progressPct = (progress.completedRegionCount / kRegions.length * 100)
        .round();
    final tour = ref.watch(onboardingTourProvider);

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/top_bar_logo.png', height: 28),
      ),
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
                child: _StatColumn(label: '진행률', value: '$progressPct%'),
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

/// 추천 여행지 배너에 그릴 데이터 묶음 — 백엔드 추천 응답과 정적 폴백 계산이 같은 구조로
/// 수렴해 배너 레이아웃은 출처를 몰라도 된다([040-home-region-recommendation]).
class _BannerContent {
  const _BannerContent({
    required this.regionId,
    required this.regionName,
    required this.dnaId,
    required this.questLabel,
    required this.quests,
  });

  final String regionId;
  final String regionName;
  final String dnaId;
  final String questLabel;
  final List<_QuestSummary> quests;
}

/// 배너의 퀘스트 요약 1건(표시 전용) — BE 퀘스트 id는 FE 정적 id와 체계가 달라 담지
/// 않는다(탭 이동은 지역 단위, [040-home-region-recommendation] 리스크 참고).
class _QuestSummary {
  const _QuestSummary({
    required this.title,
    required this.type,
    this.thumbnailUrl,
  });

  final String title;
  final String type;
  final String? thumbnailUrl;
}

/// 추천 여행지 배너 — 백엔드 추천 API 응답이 있으면 그 지역과 대표 퀘스트 요약을 보여주고,
/// 로딩·API 실패·비로그인·지역 매핑 실패면 기존 정적 계산(사용자 DNA 유형과 같은 유형
/// 퀘스트가 가장 많은 **여행 시작 전** 지역, 동률이면 전체 퀘스트 수가 많은 쪽)으로
/// 폴백한다([040-home-region-recommendation]). 두 경로 모두 "무슨 퀘스트가 있는지" 감을
/// 주도록 요약 최대 3개(DNA 유형 우선)를 함께 노출한다. 탭하면 지역 개요로 이동해 바로
/// 여행을 시작할 수 있다. 정적 폴백에서 시작 안 한 지역이 없으면 배너를 숨긴다(KAN-28).
class _RecommendedRegionBanner extends ConsumerWidget {
  const _RecommendedRegionBanner();

  /// 요약할 퀘스트 최대 개수 — 배너 높이를 크게 늘리지 않으면서 감을 주는 최소 수
  /// ([040-home-region-recommendation] 의사결정).
  static const _questSummaryMax = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(unvisitedRecommendedRegionsProvider);
    return result.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton.icon(
          onPressed: () => ref.invalidate(unvisitedRecommendedRegionsProvider),
          icon: const Icon(Icons.refresh),
          label: const Text('추천 여행지 다시 시도'),
        ),
      ),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final recommendation = items.first;
        final region = ref
            .watch(regionRepositoryProvider)
            .byId(recommendation.regionKey);
        if (region == null) return const SizedBox.shrink();
        final dnaId =
            ref.watch(currentUserProvider)?.dna ??
            ref.watch(progressProvider).dnaType ??
            'nature';
        final content = _BannerContent(
          regionId: region.id,
          regionName: region.name,
          dnaId: dnaId,
          questLabel: recommendation.matchingQuestCount > 0
              ? '${questTypeStyles[dnaId]?.label ?? dnaId} 퀘스트 ${recommendation.matchingQuestCount}개가 기다리고 있어요'
              : '퀘스트 ${recommendation.availableQuestCount}개가 기다리고 있어요',
          quests: _staticQuestSummary(
            ref.watch(questRepositoryProvider).byRegion(region.id),
            dnaId,
          ),
        );

        final dna = ref.watch(dnaRepositoryProvider).byId(content.dnaId);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => context.push('/region/${content.regionId}'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
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
                              content.regionName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              content.questLabel,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 26,
                      ),
                    ],
                  ),
                  if (content.quests.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final quest in content.quests)
                      _QuestSummaryRow(quest: quest),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 백엔드 추천 응답 → 배너 데이터. 응답에는 대표 퀘스트(최대 3개)만 담겨 지역 전체
  /// 퀘스트 개수를 알 수 없으므로 문구는 개수 없이 쓴다.
  _BannerContent _fromApi(HomeRecommendation recommendation) {
    final dnaId = recommendation.dnaCategory;
    final typeLabel = questTypeStyles[dnaId]?.label ?? dnaId;
    return _BannerContent(
      regionId: recommendation.regionId,
      regionName: recommendation.regionName,
      dnaId: dnaId,
      questLabel: '$typeLabel 퀘스트가 기다리고 있어요',
      quests: [
        for (final quest in recommendation.quests.take(_questSummaryMax))
          _QuestSummary(
            title: quest.title,
            type: quest.category,
            thumbnailUrl: quest.thumbnailUrl,
          ),
      ],
    );
  }

  /// 정적 데이터 폴백 — 기존(KAN-28) 추천 계산을 그대로 유지하고, 그 지역 퀘스트에서
  /// 요약 상위 [_questSummaryMax]개만 추가로 뽑는다. 시작 안 한 지역이 없으면 null.
  _BannerContent? _fromStaticData(WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final dnaId = progress.dnaType ?? 'nature';
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
    if (best == null) return null;

    final typeLabel = questTypeStyles[dnaId]?.label ?? dnaId;
    return _BannerContent(
      regionId: best.id,
      regionName: best.name,
      dnaId: dnaId,
      questLabel: bestMatch > 0
          ? '$typeLabel 퀘스트 $bestMatch개가 기다리고 있어요'
          : '퀘스트 $bestTotal개가 기다리고 있어요',
      quests: _staticQuestSummary(questRepo.byRegion(best.id), dnaId),
    );
  }

  /// 정적 퀘스트에서 요약 상위 [_questSummaryMax]개 — DNA 일치 우선, 같은 구간에서는
  /// 썸네일 보유 우선([040-home-region-recommendation] 요구사항). List.sort는 불안정
  /// 정렬이라 순서가 흔들리지 않게 구간 결합으로 뽑는다.
  List<_QuestSummary> _staticQuestSummary(List<Quest> quests, String dnaId) {
    bool hasThumbnail(Quest q) => q.imageUrl?.isNotEmpty ?? false;
    final ordered = [
      ...quests.where((q) => q.type == dnaId && hasThumbnail(q)),
      ...quests.where((q) => q.type == dnaId && !hasThumbnail(q)),
      ...quests.where((q) => q.type != dnaId && hasThumbnail(q)),
      ...quests.where((q) => q.type != dnaId && !hasThumbnail(q)),
    ];
    return [
      for (final quest in ordered.take(_questSummaryMax))
        _QuestSummary(
          title: quest.title,
          type: quest.type,
          thumbnailUrl: quest.imageUrl,
        ),
    ];
  }
}

/// 배너 안 퀘스트 요약 한 줄 — 유형 이모지 + 제목, 썸네일이 있으면 소형으로 함께 보여준다.
/// DNA 그라데이션 배경 위에 얹히므로 텍스트는 흰색 계열을 쓴다.
class _QuestSummaryRow extends StatelessWidget {
  const _QuestSummaryRow({required this.quest});

  final _QuestSummary quest;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = quest.thumbnailUrl;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: thumbnailUrl,
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                // 로드 전·실패 시 관광지 이미지와 같은 placeholder 색 박스를 쓴다.
                placeholder: (_, _) => Container(
                  width: 24,
                  height: 24,
                  color: AppColors.imagePlaceholderBg,
                ),
                errorWidget: (_, _, _) => Container(
                  width: 24,
                  height: 24,
                  color: AppColors.imagePlaceholderBg,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            questTypeStyles[quest.type]?.emoji ?? '📍',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              quest.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
