import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../data/models/region.dart';
import '../../data/repositories/domain_repository.dart';
import '../../data/static/quests_data.dart';
import '../../data/static/regions_data.dart';
import '../../state/domain_controller.dart';
import '../../state/progress_notifier.dart';

/// 여행 목록 — 진행 중인 여행(여행 시작함, 선택한 퀘스트 중 미완료 있음) / 지난 여행(선택한 퀘스트 전부 완료)
/// ([Figma] 여행 목록 화면, 2026-07-09 "여행 시작하기" 도입으로 지역 진행도 기준에서 변경).
/// "여행" = 지역 하나에서 "여행 시작하기"로 담은 퀘스트 묶음으로 매핑한다.
class TravelListScreen extends ConsumerWidget {
  const TravelListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journeys =
        ref.watch(domainControllerProvider).value?.journeys ??
        const <DomainJourney>[];
    final inProgress = journeys
        .where((journey) => journey.status != 'completed')
        .toList();
    final past = journeys
        .where((journey) => journey.status == 'completed')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('여행 목록'),
        actions: [
          TextButton(
            onPressed: () => context.push('/quests'),
            child: const Text('전체 퀘스트'),
          ),
        ],
      ),
      body: (inProgress.isEmpty && past.isEmpty)
          ? const Center(
              child: Text(
                '아직 시작한 여행이 없어요.\n홈 지도에서 지역을 골라 퀘스트를 시작해보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (inProgress.isNotEmpty) ...[
                  const _SectionHeader('진행중인 여행'),
                  for (final journey in inProgress)
                    _journeyCard(journey, isActive: true),
                  const SizedBox(height: 12),
                ],
                if (past.isNotEmpty) ...[
                  const _SectionHeader('지난 여행'),
                  for (final journey in past)
                    _journeyCard(journey, isActive: false),
                ],
              ],
            ),
    );
  }
}

Widget _journeyCard(DomainJourney journey, {required bool isActive}) {
  final region = regionByStableKey(journey.regionKey);
  if (region == null) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text('여행 지역 정보를 불러오지 못했어요.'),
    );
  }
  return _TripCard(journey: journey, region: region, isActive: isActive);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF222222),
        ),
      ),
    );
  }
}

class _TripCard extends ConsumerWidget {
  const _TripCard({
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
