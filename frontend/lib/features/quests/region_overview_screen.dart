import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/quest_image.dart';
import '../../core/widgets/coach_mark.dart';
import '../../core/widgets/quest_type_badge.dart' show MiniBadge;
import '../../core/widgets/trip_card.dart';
import '../../data/models/category_vocabulary.dart';
import '../../data/models/festival.dart';
import 'festival_detail_sheet.dart';
import '../../data/models/quest.dart';
import '../../data/repositories/domain_repository.dart';
import '../../state/auth_controller.dart';
import '../../state/domain_controller.dart';
import '../../state/domain_recommendation_providers.dart';
import '../../state/onboarding_tour_notifier.dart';
import '../../state/progress_notifier.dart';
import '../../state/repository_providers.dart';

/// 선택한 지역의 간결한 DNA·추천 퀘스트와 같은 지역의 진행 중 여행을 보여준다.
/// 추천은 여행 유무와 관계없이 유지하며, 새 여행 생성과 기존 여행 진입을 분리한다.
class RegionOverviewScreen extends ConsumerStatefulWidget {
  const RegionOverviewScreen({super.key, required this.regionId});

  final String regionId;

  @override
  ConsumerState<RegionOverviewScreen> createState() =>
      _RegionOverviewScreenState();
}

class _RegionOverviewScreenState extends ConsumerState<RegionOverviewScreen> {
  final _createJourneyButtonKey = GlobalKey();
  final _recommendationController = PageController(viewportFraction: 0.84);
  int _recommendedPage = 0;
  bool _createJourneyCoachHidden = false;

  @override
  void dispose() {
    _recommendationController.dispose();
    super.dispose();
  }

  void _createJourney(OnboardingTourState tour) {
    if (tour.isEnabled && tour.step == 1) {
      ref.read(onboardingTourProvider.notifier).advance();
    }
    context.push('/region/${widget.regionId}/quests');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<OnboardingTourState>(onboardingTourProvider, (previous, next) {
      final enteredThisStep =
          next.isEnabled &&
          ((previous?.isEnabled ?? false) != next.isEnabled ||
              previous?.step != next.step);
      if (enteredThisStep && _createJourneyCoachHidden) {
        setState(() => _createJourneyCoachHidden = false);
      }
    });

    final region = ref.watch(regionRepositoryProvider).byId(widget.regionId);
    if (region == null) {
      return const Scaffold(body: Center(child: Text('지역을 찾을 수 없어요')));
    }

    final tour = ref.watch(onboardingTourProvider);
    final progress = ref.watch(progressProvider);
    final dnaType = toAppCategory(
      ref.watch(currentUserProvider)?.dna ?? progress.dnaType ?? 'nature',
    );
    final dna = ref.watch(dnaRepositoryProvider).byId(dnaType);
    final dnaIconAsset = dnaCardIconAssets[dna.id];
    final dnaColors = questTypeIconColors[dna.id];
    final questRepo = ref.watch(questRepositoryProvider);
    final recommendations = ref.watch(
      recommendedQuestKeysProvider(widget.regionId),
    );
    final journeys = [
      ...?ref
          .watch(domainControllerProvider)
          .value
          ?.journeys
          .where(
            (journey) =>
                journey.regionKey == widget.regionId &&
                journey.status == 'in_progress',
          ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('여행하기'),
        titleSpacing: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              100 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppNetworkImage(
                  url: region.imageUrl,
                  height: 140,
                  borderRadius: BorderRadius.circular(14),
                  placeholderText: '${region.name} 이미지',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dnaColors?.background ?? AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      if (dnaIconAsset != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            dnaIconAsset,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        SizedBox(
                          width: 54,
                          child: Center(
                            child: Text(
                              dna.icon,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dna.name,
                              style: TextStyle(
                                color:
                                    dnaColors?.foreground ??
                                    AppColors.textStrong,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              dna.desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textStrong,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                FestivalSection(regionId: widget.regionId),
                const SizedBox(height: 18),
                const Text(
                  '추천 퀘스트',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 10),
                recommendations.when(
                  loading: () => const SizedBox(
                    height: questCardHeight,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => SizedBox(
                    height: questCardHeight,
                    child: Center(
                      child: TextButton(
                        onPressed: () => ref.invalidate(
                          recommendedQuestKeysProvider(widget.regionId),
                        ),
                        child: const Text('추천 퀘스트 다시 시도'),
                      ),
                    ),
                  ),
                  data: (keys) {
                    final quests = keys
                        .take(kRecommendedQuestSize)
                        .map(questRepo.byId)
                        .whereType<Quest>()
                        .toList();
                    if (quests.isEmpty) {
                      return const SizedBox(
                        height: questCardHeight,
                        child: Center(child: Text('추천 퀘스트가 없어요.')),
                      );
                    }
                    final page = _recommendedPage.clamp(0, quests.length - 1);
                    return Column(
                      children: [
                        SizedBox(
                          height: questCardHeight,
                          child: PageView.builder(
                            controller: _recommendationController,
                            itemCount: quests.length,
                            onPageChanged: (value) =>
                                setState(() => _recommendedPage = value),
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: _RecommendedQuestTile(
                                quest: quests[index],
                                onTap: () =>
                                    context.push('/quest/${quests[index].id}'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Semantics(
                          label: '추천 퀘스트 ${page + 1} / ${quests.length}',
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (
                                var index = 0;
                                index < quests.length;
                                index++
                              )
                                Container(
                                  width: index == page ? 14 : 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index == page
                                        ? AppColors.primaryDark
                                        : AppColors.border,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                const Text(
                  '이 지역의 내 여행',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 10),
                if (journeys.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      '진행 중인 여행이 없어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else
                  for (final journey in journeys)
                    TripCard(
                      key: ValueKey(journey.id),
                      journey: journey,
                      region: region,
                      isActive: true,
                      onTap: () => context.push('/journey/${journey.id}'),
                    ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white,
                    Colors.white,
                  ],
                  stops: const [0, 0.3, 1],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: ElevatedButton(
                    key: _createJourneyButtonKey,
                    onPressed: () => _createJourney(tour),
                    child: const Text('새 여행 만들기'),
                  ),
                ),
              ),
            ),
          ),
          if (tour.isEnabled && !_createJourneyCoachHidden)
            CoachMarkOverlay(
              targetKey: _createJourneyButtonKey,
              stepIndex: 1,
              title: '새 여행을 만들어보세요',
              body: '버튼을 누른 뒤 이번 여행에서 수행할 퀘스트를 여러 개 고를 수 있어요.',
              onBackgroundTap: () =>
                  setState(() => _createJourneyCoachHidden = true),
            ),
        ],
      ),
    );
  }
}

class _RecommendedQuestTile extends StatelessWidget {
  const _RecommendedQuestTile({required this.quest, required this.onTap});

  final Quest quest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeStyle = questTypeStyles[quest.type];
    final tagColors = questTypeIconColors[quest.type];

    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: QuestImage(
                quest: quest,
                placeholderEmoji: typeStyle?.emoji ?? '📍',
                placeholderEmojiSize: 30,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      quest.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (tagColors != null && typeStyle != null) ...[
                          MiniBadge(
                            label: typeStyle.label,
                            background: tagColors.background,
                            foreground: tagColors.foreground,
                          ),
                          const SizedBox(width: 5),
                        ],
                        if (verifyLabels[quest.verify] != null)
                          MiniBadge(
                            label: verifyLabels[quest.verify]!,
                            background: AppColors.tripMutedBadgeBg,
                            foreground: AppColors.tripMutedBadgeFg,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 지역 행사·축제 섹션(docs/specs/095-festival-info) — 진행 중·개막 예정 행사를
/// 가로 스크롤 카드로 보여준다. 로딩·실패·빈 결과는 섹션 자체를 그리지 않는다.
class FestivalSection extends ConsumerWidget {
  const FestivalSection({super.key, required this.regionId});

  final String regionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final festivals =
        ref.watch(regionFestivalsProvider(regionId)).asData?.value ??
        const <Festival>[];
    if (festivals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          '진행 중 행사·축제',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: festivals.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, index) =>
                _FestivalCard(festival: festivals[index], regionId: regionId),
          ),
        ),
      ],
    );
  }
}

class _FestivalCard extends StatelessWidget {
  const _FestivalCard({required this.festival, required this.regionId});

  final Festival festival;
  final String regionId;

  String _period() {
    String md(DateTime d) => '${d.month}.${d.day}';
    return '${md(festival.startDate)}~${md(festival.endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final ongoing = festival.isOngoing(today);
    final badgeText = ongoing ? '진행 중' : 'D-${festival.daysUntilStart(today)}';

    return SizedBox(
      width: 200,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showFestivalDetailSheet(
          context,
          festival: festival,
          regionId: regionId,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AppNetworkImage(
                  url: festival.posterUrl,
                  width: 200,
                  height: 112,
                  borderRadius: BorderRadius.circular(12),
                  placeholderEmoji: '🎪',
                  placeholderEmojiSize: 30,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ongoing ? AppColors.primaryDark : Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              festival.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              '${_period()} · ${festival.placeName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
