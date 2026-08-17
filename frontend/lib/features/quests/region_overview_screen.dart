import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_network_image.dart';

import '../../core/widgets/coach_mark.dart';
import '../../core/widgets/quest_type_badge.dart' show MiniBadge;
import '../../data/models/quest.dart';
import '../../data/repositories/domain_repository.dart'
    show DomainJourney, kRecommendedQuestSize;

import '../../state/domain_controller.dart';
import '../../state/domain_recommendation_providers.dart';
import '../../state/onboarding_tour_notifier.dart';
import '../../state/progress_notifier.dart';
import '../../state/repository_providers.dart';

/// 여행하기 — 지도에서 지역을 탭하면 처음 보는 화면. Figma 스펙(2026-07-09 공유) 반영:
/// 지역 이미지 placeholder, DNA 요약 카드, 추천 퀘스트 3건(정보만, 수행 버튼 없음),
/// "퀘스트 선택하러 가기" → 퀘스트 선택 화면. 여행이 이미 시작된 지역이면 대신 "내 여행 퀘스트"
/// 목록을 보여준다(2026-07-09 사용자 확정 — 퀘스트 선택은 다중 선택이며, 그 자리에서 수행하지 않는다).
/// 온보딩 투어 2단계("퀘스트 선택하러 가기" 버튼)·4단계("내 여행 퀘스트" 탭)를 코치마크로 안내한다.
class RegionOverviewScreen extends ConsumerStatefulWidget {
  const RegionOverviewScreen({
    super.key,
    required this.regionId,
    this.journeyId,
  });

  final String regionId;
  final String? journeyId;

  @override
  ConsumerState<RegionOverviewScreen> createState() =>
      _RegionOverviewScreenState();
}

class _RegionOverviewScreenState extends ConsumerState<RegionOverviewScreen> {
  // 다른 지역의 RegionOverviewScreen이 스택에 동시에 남아 있어도(예: 라우트 전환 애니메이션,
  // 브라우저 뒤로/앞으로가기) GlobalKey가 중복되지 않도록 인스턴스별로 소유한다.
  final _selectQuestButtonKey = GlobalKey();
  final _firstTripQuestKey = GlobalKey();

  void _goToQuestSelect(
    BuildContext context,
    String regionId,
    OnboardingTourState tour,
  ) {
    if (!tour.isDone && tour.step == 1) {
      ref.read(onboardingTourProvider.notifier).advance();
    }
    context.push('/region/$regionId/quests');
  }

  @override
  Widget build(BuildContext context) {
    final regionId = widget.regionId;
    final region = ref.watch(regionRepositoryProvider).byId(regionId);
    if (region == null) {
      return const Scaffold(body: Center(child: Text('지역을 찾을 수 없어요')));
    }
    final tour = ref.watch(onboardingTourProvider);
    final questRepo = ref.watch(questRepositoryProvider);
    final progress = ref.watch(progressProvider);
    final dnaType = progress.dnaType ?? 'nature';
    final dna = ref.watch(dnaRepositoryProvider).byId(dnaType);
    final journeys =
        ref.watch(domainControllerProvider).value?.journeys ??
        const <DomainJourney>[];
    final selectedJourney = widget.journeyId == null
        ? null
        : journeys
              .where((journey) => journey.id == widget.journeyId)
              .firstOrNull;
    final tripQuests =
        selectedJourney?.questKeys.toSet() ?? const <String>{};
    final tripStarted = tripQuests.isNotEmpty;
    final journeyQuery = selectedJourney == null
        ? ''
        : '?journeyId=${selectedJourney.id}';

    final recommendedQuestKeys = tripStarted
        ? null
        : ref.watch(recommendedQuestKeysProvider(regionId));

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('여행하기'),
        titleSpacing: 0,
      ),
      // 이 버튼은 본문 하단 Positioned(아래 body Stack)에 둔다 — bottomNavigationBar에
      // 두면 코치마크(body Stack 안에서만 그려짐)가 닿을 수 없는 영역이라 스포트라이트가
      // 전혀 보이지 않는다. (과거 이 버튼이 두 곳에 동시에 떠 있던 GlobalKey 중복 버그도
      // 함께 있었음 — 이제 body 쪽 하나만 남긴다.)
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
                // 지역 대표 이미지(TourAPI) — 없으면 기존 안내 placeholder
                // ([045-quest-region-images]).
                AppNetworkImage(
                  url: region.imageUrl,
                  height: 140,
                  borderRadius: BorderRadius.circular(14),
                  placeholderText: '${region.name} 이미지',
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
                  for (final (index, questId) in tripQuests.toList().indexed)
                    if (questRepo.byId(questId) case final quest?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _TripQuestTile(
                          key: index == 0 ? _firstTripQuestKey : null,
                          quest: quest,

                          done: progress.isCompleted(quest.id),
                          onTap: () {
                            if (index == 0 && !tour.isDone && tour.step == 3) {
                              ref
                                  .read(onboardingTourProvider.notifier)
                                  .advance();
                            }
                            if (progress.isCompleted(quest.id)) {
                              context.push('/quest/${quest.id}');
                            } else {
                              context.push(
                                '/quest/${quest.id}/verify$journeyQuery',
                              );
                            }
                          },
                        ),
                      ),
                  // The duplicate '퀘스트 더 선택하기' button was removed from here.
                ] else ...[
                  const Text(
                    '추천 퀘스트',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  recommendedQuestKeys?.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => TextButton(
                          onPressed: () => ref.invalidate(
                            recommendedQuestKeysProvider(regionId),
                          ),
                          child: const Text('추천 퀘스트 다시 시도'),
                        ),
                        data: (keys) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final questKey in keys.take(
                              kRecommendedQuestSize,
                            ))
                              if (questRepo.byId(questKey) case final quest?)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _RecommendedQuestTile(
                                    quest: quest,

                                    onTap: () =>
                                        context.push('/quest/${quest.id}'),
                                  ),
                                ),
                          ],
                        ),
                      ) ??
                      const SizedBox.shrink(),
                  const SizedBox(height: 24),
                ],
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
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: tripStarted
                      ? OutlinedButton(
                          onPressed: () => context.push(
                            '/region/$regionId/quests$journeyQuery',
                          ),
                          child: const Text('퀘스트 더 선택하기'),
                        )
                      : ElevatedButton(
                          key: _selectQuestButtonKey,
                          onPressed: () =>
                              _goToQuestSelect(context, regionId, tour),
                          child: const Text('퀘스트 선택하러 가기'),
                        ),
                ),
              ),
            ),
          ),
          if (!tour.isDone && tour.step == 1 && !tripStarted)
            CoachMarkOverlay(
              targetKey: _selectQuestButtonKey,
              stepIndex: 1,
              title: '퀘스트를 선택해보세요',
              body:
                  '추천 퀘스트를 확인하고 "퀘스트 선택하러 가기"를 누르면\n'
                  '이번 여행에서 수행할 퀘스트를 여러 개 고를 수 있어요.',
            ),
          if (!tour.isDone && tour.step == 3 && tripStarted)
            CoachMarkOverlay(
              targetKey: _firstTripQuestKey,
              stepIndex: 3,
              title: '퀘스트를 인증해보세요',
              body: '퀘스트를 누르면 인증 화면으로 이동해요.\n사진·GPS·퀴즈로 인증하면 퀘스트가 완료돼요.',
            ),
        ],
      ),
    );
  }
}

class _TripQuestTile extends StatelessWidget {
  const _TripQuestTile({
    super.key,
    required this.quest,

    required this.done,
    required this.onTap,
  });

  final Quest quest;

  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeStyle = questTypeStyles[quest.type];
    final tagColors = questTypeIconColors[quest.type];

    return SizedBox(
      height: questCardHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  // 관광지 썸네일(TourAPI) — 없으면 기존 유형 이모지 placeholder
                  // ([045-quest-region-images]).
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: AppNetworkImage(
                      url: quest.imageUrl,
                      placeholderEmoji: typeStyle?.emoji ?? '📍',
                      placeholderEmojiSize: 32,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          quest.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (tagColors != null && typeStyle != null) ...[
                              MiniBadge(
                                label: typeStyle.label,
                                background: tagColors.background,
                                foreground: tagColors.foreground,
                              ),
                              const SizedBox(width: 6),
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
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Center(
                    child: Icon(
                      done ? Icons.check_circle : Icons.chevron_right,
                      color: done
                          ? AppColors.primaryDark
                          : AppColors.timelineDotGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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

    return SizedBox(
      height: questCardHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  // 관광지 썸네일(TourAPI) — 없으면 기존 유형 이모지 placeholder
                  // ([045-quest-region-images]).
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: AppNetworkImage(
                      url: quest.imageUrl,
                      placeholderEmoji: typeStyle?.emoji ?? '📍',
                      placeholderEmojiSize: 32,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          quest.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (tagColors != null && typeStyle != null) ...[
                              MiniBadge(
                                label: typeStyle.label,
                                background: tagColors.background,
                                foreground: tagColors.foreground,
                              ),
                              const SizedBox(width: 6),
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
        ),
      ),
    );
  }
}
