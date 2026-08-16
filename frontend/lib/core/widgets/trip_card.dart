import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/region.dart';
import '../../data/repositories/domain_repository.dart';
import '../../data/static/quests_data.dart';
import '../../data/static/regions_data.dart';
import '../../state/progress_notifier.dart';
import '../constants.dart';

/// 여행 카드 — 제목·기간·지역 태그·(진행중이면) 퀘스트 진행도를 보여준다.
/// 여행 목록(`/travel`, `travel_list_screen.dart`)과 여행 타임라인(`/timeline`,
/// `timeline_screen.dart`)의 여행 그룹 헤더가 공유한다([080-timeline-journey-grouping]).
class TripCard extends ConsumerWidget {
  const TripCard({
    super.key,
    required this.journey,
    required this.region,
    required this.isActive,
    this.onEdit,
    this.onDelete,
  });

  final DomainJourney journey;
  final Region region;
  final bool isActive;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final trip = journey.questKeys;
    final total = trip.length;
    final done = trip.where(progress.isCompleted).length;
    final uniqueVerifies = trip
        .map((qId) => kQuests.where((q) => q.id == qId).firstOrNull?.verify)
        .whereType<String>()
        .toSet();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () =>
            context.push('/region/${region.id}?journeyId=${journey.id}'),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      journey.title ?? tripTitleFor(region),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onEdit != null || onDelete != null)
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: PopupMenuButton<_TripCardAction>(
                        tooltip: '여행 관리',
                        padding: EdgeInsets.zero,
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
                              child: Text('여행 정보 수정'),
                            ),
                          if (onDelete != null)
                            const PopupMenuItem(
                              value: _TripCardAction.delete,
                              child: Text('여행 삭제'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              if (journey.startDate != null && journey.endDate != null) ...[
                const SizedBox(height: 2),
                Text(
                  _periodLabel(journey.startDate!, journey.endDate!),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.timelineDateText,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final v in uniqueVerifies)
                    if (verifyLabels[v] != null) ...[
                      _Badge(
                        label: verifyLabels[v]!,
                        background: isActive
                            ? AppColors.tripActiveBadgeBg
                            : AppColors.tripMutedBadgeBg,
                        foreground: isActive
                            ? AppColors.tripActiveBadgeFg
                            : AppColors.tripMutedBadgeFg,
                      ),
                      const SizedBox(width: 6),
                    ],
                  if (isActive) ...[
                    const Spacer(),
                    Text(
                      '퀘스트 $done/$total',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tripProgressText,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _periodLabel(DateTime start, DateTime end) {
    String md(DateTime value) =>
        '${value.month.toString().padLeft(2, '0')}.'
        '${value.day.toString().padLeft(2, '0')}';
    return '${start.year}.${md(start)} ~ ${md(end)}';
  }
}

enum _TripCardAction { edit, delete }

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: foreground,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
