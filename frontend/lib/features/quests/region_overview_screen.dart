import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/chungbuk_map.dart';
import '../../core/widgets/coach_mark.dart';
import '../../data/models/quest.dart';
import '../../state/onboarding_tour_notifier.dart';
import '../../state/progress_notifier.dart';
import '../../state/repository_providers.dart';

/// 여행하기 — 지도에서 지역을 탭하면 처음 보는 화면. Figma 스펙(2026-07-09 공유) 반영:
/// 지역 이미지 placeholder, DNA 요약 카드, 추천 퀘스트 2건(정보만, 수행 버튼 없음),
/// "퀘스트 선택하러 가기" → 퀘스트 선택 화면. 여행이 이미 시작된 지역이면 대신 "내 여행 퀘스트"
/// 목록을 보여준다(2026-07-09 사용자 확정 — 퀘스트 선택은 다중 선택이며, 그 자리에서 수행하지 않는다).
/// 온보딩 투어 2단계("퀘스트 선택하러 가기" 버튼)·4단계("내 여행 퀘스트" 탭)를 코치마크로 안내한다.
class RegionOverviewScreen extends ConsumerStatefulWidget {
  const RegionOverviewScreen({super.key, required this.regionId});

  final String regionId;

  @override
  ConsumerState<RegionOverviewScreen> createState() =>
      _RegionOverviewScreenState();
}

class _RegionOverviewScreenState extends ConsumerState<RegionOverviewScreen> {
  // 다른 지역의 RegionOverviewScreen이 스택에 동시에 남아 있어도(예: 라우트 전환 애니메이션,
  // 브라우저 뒤로/앞으로가기) GlobalKey가 중복되지 않도록 인스턴스별로 소유한다.
  final _selectQuestButtonKey = GlobalKey();
  final _firstTripQuestKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final regionId = widget.regionId;
    final region = ref.watch(regionRepositoryProvider).byId(regionId);
    if (region == null) {
      return const Scaffold(body: Center(child: Text('지역을 찾을 수 없어요')));
    }
    final tour = ref.watch(onboardingTourProvider);
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
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('여행하기'),
        titleSpacing: 0,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: tripStarted
              ? OutlinedButton(
                  onPressed: () => context.push('/region/$regionId/quests'),
                  child: const Text('퀘스트 더 선택하기'),
                )
              : ElevatedButton(
                  key: _selectQuestButtonKey,
                  onPressed: () => context.push('/region/$regionId/quests'),
                  child: const Text('퀘스트 선택하러 가기'),
                ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
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
                          regionName: region.name,
                          done: progress.isCompleted(quest.id),
                          onTap: () => progress.isCompleted(quest.id)
                              ? context.push('/quest/${quest.id}')
                              : context.push('/quest/${quest.id}/verify'),
                        ),
                      ),
                  const SizedBox(height: 12),
                ] else ...[
                  const Text(
                    '추천 퀘스트',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  for (final quest in recommended)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _RecommendedQuestTile(
                        quest: quest,
                        regionName: region.name,
                        onTap: () => context.push('/quest/${quest.id}'),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ],
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
    final typeStyle = questTypeStyles[quest.type];
    final tagColors = questTypeIconColors[quest.type];
    final regionColor = mapFillColors(quest.region, 1);

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
                            _MiniBadge(
                              label: regionName,
                              background: regionColor.background,
                              foreground: regionColor.label,
                            ),
                            if (tagColors != null && typeStyle != null) ...[
                              const SizedBox(width: 6),
                              _MiniBadge(
                                label: typeStyle.label,
                                background: tagColors.background,
                                foreground: tagColors.foreground,
                              ),
                            ],
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
    final typeStyle = questTypeStyles[quest.type];
    final tagColors = questTypeIconColors[quest.type];
    final regionColor = mapFillColors(quest.region, 1);

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
                            _MiniBadge(
                              label: regionName,
                              background: regionColor.background,
                              foreground: regionColor.label,
                            ),
                            if (tagColors != null && typeStyle != null) ...[
                              const SizedBox(width: 6),
                              _MiniBadge(
                                label: typeStyle.label,
                                background: tagColors.background,
                                foreground: tagColors.foreground,
                              ),
                            ],
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
