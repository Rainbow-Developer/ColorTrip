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
  });

  final DomainJourney journey;
  final Region region;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final trip = journey.questKeys;
    final total = trip.length;
    final done = trip.where(progress.isCompleted).length;
    final dominantType = dominantTypeForRegion(region.id);
    final typeLabel = questTypeStyles[dominantType]?.label ?? dominantType;

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
              Text(
                journey.title ?? tripTitleFor(region),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
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
                  _Badge(
                    label: region.name,
                    background: isActive
                        ? AppColors.tripActiveBadgeBg
                        : AppColors.tripMutedBadgeBg,
                    foreground: isActive
                        ? AppColors.tripActiveBadgeFg
                        : AppColors.tripMutedBadgeFg,
                  ),
                  const SizedBox(width: 6),
                  if (typeLabel != null)
                    _Badge(
                      label: typeLabel,
                      background: AppColors.tripMutedBadgeBg,
                      foreground: AppColors.tripMutedBadgeFg,
                    ),
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
