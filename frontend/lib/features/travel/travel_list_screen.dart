import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/chungbuk_map.dart';
import '../../data/models/region.dart';
import '../../data/static/quests_data.dart';
import '../../data/static/regions_data.dart';
import '../../state/progress_notifier.dart';
import '../../state/progress_state.dart';

/// 여행 목록 — 진행 중인 여행(여행 시작함, 선택한 퀘스트 중 미완료 있음) / 지난 여행(선택한 퀘스트 전부 완료)
/// ([Figma] 여행 목록 화면, 2026-07-09 "여행 시작하기" 도입으로 지역 진행도 기준에서 변경).
/// "여행" = 지역 하나에서 "여행 시작하기"로 담은 퀘스트 묶음으로 매핑한다.
class TravelListScreen extends ConsumerWidget {
  const TravelListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);

    final inProgress = <Region>[];
    final past = <Region>[];
    for (final region in kRegionsInMapOrder) {
      switch (progress.tripStatusOf(region.id)) {
        case RegionTripStatus.notStarted:
          break;
        case RegionTripStatus.inProgress:
          inProgress.add(region);
        case RegionTripStatus.completed:
          past.add(region);
      }
    }

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
                  for (final region in inProgress)
                    _TripCard(region: region, isActive: true),
                  const SizedBox(height: 12),
                ],
                if (past.isNotEmpty) ...[
                  const _SectionHeader('지난 여행'),
                  for (final region in past)
                    _TripCard(region: region, isActive: false),
                ],
              ],
            ),
    );
  }
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
  const _TripCard({required this.region, required this.isActive});

  final Region region;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final trip = progress.tripQuestsOf(region.id);
    final tripInfo = progress.tripInfoOf(region.id);
    final total = trip.length;
    final done = trip.where(progress.isCompleted).length;
    final dominantType = dominantTypeForRegion(region.id);
    final typeStyle = questTypeStyles[dominantType];
    final tagColors = questTypeIconColors[dominantType];
    final regionColor = mapFillColors(region.id, 1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
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
              onTap: () => context.push('/region/${region.id}'),
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Container(
                            color: AppColors.imagePlaceholderBg,
                            alignment: Alignment.center,
                            child: Text(
                              typeStyle?.emoji ?? '📍',
                              style: const TextStyle(fontSize: 32),
                            ),
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
                                // 여행 시작 시 입력한 이름 우선, 없으면(과거 데이터) 지역명 기반 기본값.
                                tripInfo?.name ?? tripTitleFor(region),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (tripInfo != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  tripInfo.periodLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.timelineDateText,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _Badge(
                                    label: region.name,
                                    background: regionColor.background,
                                    foreground: regionColor.label,
                                  ),
                                  if (typeStyle != null &&
                                      tagColors != null) ...[
                                    const SizedBox(width: 6),
                                    _Badge(
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
                      if (isActive) const SizedBox(width: 48),
                    ],
                  ),
                  if (isActive)
                    Positioned(
                      right: 14,
                      bottom: 10,
                      child: Text(
                        '$done/$total',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tripProgressText,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
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
