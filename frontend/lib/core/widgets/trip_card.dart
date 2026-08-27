import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/region.dart';
import '../../data/repositories/domain_repository.dart';
import '../../data/static/quests_data.dart';
import '../../data/static/regions_data.dart';
import '../../state/progress_notifier.dart';
import '../constants.dart';

/// 요일 라벨 — [DateTime.weekday]는 월요일=1 ~ 일요일=7이라 인덱스를 그대로 맞춘다.
const _koreanWeekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 여행 카드 — 제목·기간(요일 포함)·퀘스트 유형 태그·(진행중이면) 퀘스트 진행도를 보여준다.
/// 여행 목록(`/travel`, `travel_list_screen.dart`)과 여행하기(`/region/:id`,
/// `region_overview_screen.dart`)가 공유한다([080-timeline-journey-grouping]).
class TripCard extends ConsumerWidget {
  const TripCard({
    super.key,
    required this.journey,
    required this.region,
    required this.isActive,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final DomainJourney journey;
  final Region region;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final trip = journey.questKeys;
    final total = trip.length;
    final done = trip.where(progress.isCompleted).length;
    final uniqueTypes = trip
        .map((qId) => kQuests.where((q) => q.id == qId).firstOrNull?.type)
        .whereType<String>()
        .toSet();
    final questProgress = total == 0 ? 0.0 : done / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      journey.title ?? tripTitleFor(region),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onEdit != null || onDelete != null)
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: PopupMenuButton<_TripCardAction>(
                        tooltip: '여행 관리',
                        // 여행 탭(셸 안) 목록 맨 아래 카드에서 열면 메뉴가 떠 있는
                        // 하단탭 뒤로 깔려 눌리지 않으므로 루트 내비게이터에 띄운다.
                        useRootNavigator: true,
                        padding: EdgeInsets.zero,
                        color: Colors.white,
                        elevation: 4,
                        shadowColor: Colors.black.withValues(alpha: 0.16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(
                            color: AppColors.tripCardMenuBorder,
                          ),
                        ),
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (action) {
                          switch (action) {
                            case _TripCardAction.edit:
                              onEdit?.call();
                              break;
                            case _TripCardAction.delete:
                              onDelete?.call();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          if (onEdit != null)
                            const PopupMenuItem(
                              value: _TripCardAction.edit,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: AppColors.textBody,
                                  ),
                                  SizedBox(width: 10),
                                  Text('여행 정보 수정'),
                                ],
                              ),
                            ),
                          if (onDelete != null)
                            const PopupMenuItem(
                              value: _TripCardAction.delete,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppColors.danger,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    '여행 삭제',
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              if (journey.startDate != null && journey.endDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: AppColors.timelineDateText,
                    ),
                    const SizedBox(width: 5),
                    _PeriodText(
                      start: journey.startDate!,
                      end: journey.endDate!,
                    ),
                  ],
                ),
              ],
              if (uniqueTypes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final type in uniqueTypes)
                      if (questTypeStyles[type] case final style?)
                        _Badge(
                          label: style.label,
                          background: style.background,
                          foreground: style.foreground,
                        ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: AppColors.border.withValues(alpha: 0.5),
              ),
              if (isActive) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      '퀘스트',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBody,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$done/$total',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tripProgressText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: questProgress,
                          minHeight: 6,
                          backgroundColor: AppColors.verifyProgressTrack,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TripCardAction { edit, delete }

/// 여행 기간 라벨 — "2026.08.18 (화) ~ 08.21 (금)".
class _PeriodText extends StatelessWidget {
  const _PeriodText({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    String md(DateTime value) =>
        '${value.month.toString().padLeft(2, '0')}.'
        '${value.day.toString().padLeft(2, '0')} '
        '(${_koreanWeekdays[value.weekday - 1]})';

    return Text(
      '${start.year}.${md(start)} ~ ${md(end)}',
      style: const TextStyle(fontSize: 12, color: AppColors.textBody),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    // 퀘스트 목록(quest_list_screen.dart)의 _Tag와 같은 크기로 맞춘다.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
