import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/chungbuk_map.dart';
import '../../core/widgets/coach_mark.dart';
import '../../core/widgets/map_legend.dart';
import '../../data/repositories/quest_repository.dart';
import '../../data/repositories/region_repository.dart';
import '../../data/static/regions_data.dart';
import '../../state/auth_controller.dart';
import '../../state/domain_recommendation_providers.dart';
import '../../state/onboarding_tour_notifier.dart';
import '../../state/progress_notifier.dart';
import '../../state/progress_state.dart';
import '../../state/repository_providers.dart';

/// 홈 화면에 하나만 존재하므로 모듈 전역 키로 충분하다(코치마크가 지도 위치를 측정하는 용도).
final _mapKey = GlobalKey();

/// 홈(지도) — Figma 스펙(2026-07-08 공유) 반영: 추천 여행지 배너(KAN-28),
/// 지도 색칠(범례 포함), 최근 완료 섹션. 진행도는 지도 좌상단의 작은 배지로 압축하고,
/// 공유 버튼은 지도 우상단에 붙여 무엇을 공유하는지 헷갈리지 않게 한다(2026-07-11 KAN-029).
/// 온보딩 투어 1단계로 지도를 코치마크로 안내한다(KAN-040 피드백 — 텍스트 설명 대신 실제
/// 화면에 화살표로 표시).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();
  bool _mapCoachHidden = false;
  bool _resettingMapCoach = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _hideMapCoach() {
    setState(() => _mapCoachHidden = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _resetMapCoachForRestart() {
    setState(() {
      _mapCoachHidden = false;
      _resettingMapCoach = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      setState(() => _resettingMapCoach = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<OnboardingTourState>(onboardingTourProvider, (previous, next) {
      final restarted =
          (previous?.isDone ?? true) && !next.isDone && next.step == 0;
      if (restarted) {
        _resetMapCoachForRestart();
      }
    });

    final progress = ref.watch(progressProvider);
    final progressPct = (progress.completedRegionCount / kRegions.length * 100)
        .round();
    final tour = ref.watch(onboardingTourProvider);
    final showMapCoach =
        !tour.isDone &&
        tour.step == 0 &&
        !_mapCoachHidden &&
        !_resettingMapCoach;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/top_bar_logo.png', height: 28),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              physics: showMapCoach
                  ? const NeverScrollableScrollPhysics()
                  : null,
              padding: EdgeInsets.fromLTRB(20, 20, 20, showMapCoach ? 360 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _RecommendedRegionBanner(),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _CompactProgressBar(
                              completedJourneyCount:
                                  progress.completedJourneyCount,
                              coloringPct: progressPct,
                            ),
                          ),
                          IconButton(
                            onPressed: () => context.push('/share'),
                            tooltip: '공유하기',
                            icon: const Icon(Icons.ios_share, size: 22),
                            color: AppColors.primaryDark,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 44,
                              height: 40,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      KeyedSubtree(
                        key: _mapKey,
                        child: ChungbukMap(
                          regionSaturation: {
                            for (final region in kRegions)
                              region.id: progress.regionSaturation(region.id),
                          },
                          onRegionTap: (regionId) {
                            if (!tour.isDone && tour.step == 0) {
                              ref
                                  .read(onboardingTourProvider.notifier)
                                  .advance();
                            }
                            context.push('/region/$regionId');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const MapLegend(),
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
            if (showMapCoach)
              CoachMarkOverlay(
                targetKey: _mapKey,
                stepIndex: 0,
                title: '지도에서 지역을 눌러보세요',
                body: '가고 싶은 지역을 누르면 추천 퀘스트를 볼 수 있어요.',
                // 지도가 화면의 상당 부분을 차지해 중앙 정렬 시 말풍선이 지도(하이라이팅)와
                // 겹치는 문제(KAN-071) — 뷰포트 상단 쪽으로 정렬해 아래쪽에 공간을 확보한다.
                // 0.0(완전히 붙임)은 화면 패딩이 사라져 지도가 앱바에 딱 붙어 보이므로,
                // 약간의 여백이 남도록 0을 살짝 넘는 값을 쓴다.
                scrollAlignment: 0.03,
                forceBubbleBelow: true,
                onBackgroundTap: _hideMapCoach,
              ),
          ],
        ),
      ),
    );
  }
}

class _CompactProgressBar extends StatelessWidget {
  const _CompactProgressBar({
    required this.completedJourneyCount,
    required this.coloringPct,
  });

  final int completedJourneyCount;
  final int coloringPct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth < 105
              ? constraints.maxWidth
              : 105.0;
          return Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ProgressMetric(label: '여행 완료', value: '$completedJourneyCount'),
              _ProgressMetric(label: '채색률', value: '$coloringPct%'),
              SizedBox(
                width: barWidth,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: coloringPct / 100,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFEEEEEA),
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(
              color: AppColors.formLabel,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111111),
      ),
    );
  }
}

/// 추천 여행지 배너에 그릴 데이터 묶음 — 서버 추천 응답을 배너 레이아웃이 소비하는
/// 표시 전용 형태로 정규화한다([065-quest-recommendation-api]).
class _BannerContent {
  const _BannerContent({
    required this.regionId,
    required this.regionName,
    required this.questLabel,
    required this.quests,
  });

  final String regionId;
  final String regionName;
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

/// 추천 여행지 배너 — 서버 추천(`GET /regions/unvisited`)의 첫 후보 지역과, 그 지역의
/// 추천 퀘스트(`GET /quests/recommended`) 요약 최대 3개를 보여준다
/// ([065-quest-recommendation-api]). 정적 폴백은 두지 않는다 — 로딩 중에는 배너를 숨기고,
/// API 실패는 재시도 버튼으로 노출해 오래된 추천을 진짜처럼 보여주지 않는다. 서버가 준
/// 지역 중 정적 카탈로그에 매핑되는 첫 항목을 쓰며, 하나도 매핑되지 않으면 숨긴다.
/// 탭하면 지역 개요로 이동해 바로 여행을 시작할 수 있다(KAN-28).
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
        final regionRepo = ref.watch(regionRepositoryProvider);
        final resolved = [
          for (final item in items)
            if (regionRepo.byId(item.regionKey) case final region?)
              (item, region),
        ].firstOrNull;
        if (resolved == null) return const SizedBox.shrink();
        final (recommendation, region) = resolved;
        final dnaId =
            ref.watch(currentUserProvider)?.dna ??
            ref.watch(progressProvider).dnaType ??
            'nature';
        final recommendedQuestKeys = ref.watch(
          recommendedQuestKeysProvider(recommendation.regionKey),
        );
        return recommendedQuestKeys.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () => ref.invalidate(
                recommendedQuestKeysProvider(recommendation.regionKey),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('추천 퀘스트 다시 시도'),
            ),
          ),
          data: (keys) {
            final questRepo = ref.watch(questRepositoryProvider);
            final dna = ref.watch(dnaRepositoryProvider).byId(dnaId);
            final dnaColors = questTypeIconColors[dna.id];
            final content = _BannerContent(
              regionId: region.id,
              regionName: region.name,
              questLabel: recommendation.matchingQuestCount > 0
                  ? '${questTypeStyles[dna.id]?.label ?? dna.id} 퀘스트 ${recommendation.matchingQuestCount}개가 기다리고 있어요'
                  : '퀘스트 ${recommendation.availableQuestCount}개가 기다리고 있어요',
              quests: [
                for (final key in keys.take(_questSummaryMax))
                  if (questRepo.byId(key) case final quest?)
                    _QuestSummary(
                      title: quest.title,
                      type: quest.type,
                      thumbnailUrl: quest.imageUrl,
                    ),
              ],
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => context.push('/region/${content.regionId}'),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: dnaColors?.background ?? AppColors.surfaceMuted,
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
                                  style: TextStyle(
                                    color:
                                        dnaColors?.foreground ??
                                        AppColors.textBody,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  content.regionName,
                                  style: const TextStyle(
                                    color: AppColors.textStrong,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  content.questLabel,
                                  style: const TextStyle(
                                    color: AppColors.textBody,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: dnaColors?.foreground ?? AppColors.textBody,
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
      },
    );
  }
}

/// 배너 안 퀘스트 요약 한 줄 — 유형 이모지 + 제목, 썸네일이 있으면 소형으로 함께 보여준다.
/// DNA 카드 배경(questTypeIconColors 연한 배경색) 위에 얹히므로 텍스트는 짙은 색을 쓴다.
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
                color: AppColors.textStrong,
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
