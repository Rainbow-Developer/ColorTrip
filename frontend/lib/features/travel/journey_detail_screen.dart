import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/coach_mark.dart';
import '../../core/widgets/quest_type_badge.dart' show MiniBadge;
import '../../data/models/quest.dart';
import '../../data/static/regions_data.dart';
import '../../state/domain_controller.dart';
import '../../state/onboarding_tour_notifier.dart';
import '../../state/progress_notifier.dart';
import '../../state/repository_providers.dart';

/// 한 여행의 정보·진행도·선택 퀘스트만 보여주는 상세 화면.
class JourneyDetailScreen extends ConsumerStatefulWidget {
  const JourneyDetailScreen({super.key, required this.journeyId});

  final String journeyId;

  @override
  ConsumerState<JourneyDetailScreen> createState() =>
      _JourneyDetailScreenState();
}

class _JourneyDetailScreenState extends ConsumerState<JourneyDetailScreen> {
  final _firstQuestKey = GlobalKey();
  bool _firstQuestCoachHidden = false;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(domainControllerProvider);
    return snapshot.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _JourneyNotFound(),
      data: (value) {
        final journey = value.journeys
            .where((item) => item.id == widget.journeyId)
            .firstOrNull;
        if (journey == null) return const _JourneyNotFound();
        final region = regionByStableKey(journey.regionKey);
        if (region == null) return const _JourneyNotFound();

        final questRepo = ref.watch(questRepositoryProvider);
        final progress = ref.watch(progressProvider);
        final quests = journey.questKeys
            .map(questRepo.byId)
            .whereType<Quest>()
            .toList();
        final done = quests
            .where((quest) => progress.isCompleted(quest.id))
            .length;
        final active = journey.status == 'in_progress';
        final tour = ref.watch(onboardingTourProvider);

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackLocation: '/travel'),
            title: const Text('여행 상세'),
            titleSpacing: 0,
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  (active ? 100 : 20) + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  Text(
                    journey.title ?? tripTitleFor(region),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (journey.startDate != null && journey.endDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _periodLabel(journey.startDate!, journey.endDate!),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.tripActiveBadgeBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: quests.isEmpty ? 0 : done / quests.length,
                              minHeight: 7,
                              backgroundColor: Colors.white,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '퀘스트 $done/${quests.length}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    '선택한 퀘스트',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (quests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        '선택한 퀘스트가 없어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  else
                    for (final (index, quest) in quests.indexed)
                      Padding(
                        key: index == 0 ? _firstQuestKey : null,
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _JourneyQuestTile(
                          quest: quest,
                          done: progress.isCompleted(quest.id),
                          onTap: () {
                            if (index == 0 && !tour.isDone && tour.step == 3) {
                              ref
                                  .read(onboardingTourProvider.notifier)
                                  .advance();
                            }
                            if (!active || progress.isCompleted(quest.id)) {
                              context.push('/quest/${quest.id}');
                            } else {
                              context.push(
                                '/quest/${quest.id}/verify?journeyId=${journey.id}',
                              );
                            }
                          },
                        ),
                      ),
                ],
              ),
              if (active)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.white,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: ElevatedButton(
                          onPressed: () => context.push(
                            '/region/${journey.regionKey}/quests?journeyId=${journey.id}',
                          ),
                          child: const Text('퀘스트 수정하기'),
                        ),
                      ),
                    ),
                  ),
                ),
              if (!tour.isDone &&
                  tour.step == 3 &&
                  quests.isNotEmpty &&
                  !_firstQuestCoachHidden)
                CoachMarkOverlay(
                  targetKey: _firstQuestKey,
                  stepIndex: 3,
                  title: '퀘스트를 인증해보세요',
                  body: '퀘스트를 누르면 인증 화면으로 이동해요. 인증을 마치면 진행도에 반영돼요.',
                  onBackgroundTap: () =>
                      setState(() => _firstQuestCoachHidden = true),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _JourneyNotFound extends StatelessWidget {
  const _JourneyNotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(fallbackLocation: '/travel')),
      body: const Center(child: Text('여행을 찾을 수 없어요.')),
    );
  }
}

class _JourneyQuestTile extends StatelessWidget {
  const _JourneyQuestTile({
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
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: questCardHeight,
          child: Row(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: AppNetworkImage(
                  url: quest.imageUrl,
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
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (tagColors != null && typeStyle != null)
                        MiniBadge(
                          label: typeStyle.label,
                          background: tagColors.background,
                          foreground: tagColors.foreground,
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  done ? Icons.check_circle : Icons.chevron_right,
                  color: done ? AppColors.primaryDark : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _periodLabel(DateTime start, DateTime end) {
  String md(DateTime value) =>
      '${value.month.toString().padLeft(2, '0')}.'
      '${value.day.toString().padLeft(2, '0')}';
  return '${start.year}.${md(start)} ~ ${md(end)}';
}
