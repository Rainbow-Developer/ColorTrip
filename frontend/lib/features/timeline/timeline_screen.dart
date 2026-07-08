import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/filter_chip_row.dart';
import '../../data/repositories/quest_repository.dart';
import '../../data/repositories/region_repository.dart';
import '../../state/progress_notifier.dart';
import '../../state/progress_state.dart';
import '../../state/repository_providers.dart';

/// 여행 타임라인 — Figma 스펙(2026-07-08 공유) 반영: 월별 필터 칩, 월별 그룹 헤더,
/// 점+선으로 이어지는 타임라인 카드(마지막 항목만 회색 점).
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  String _filter = 'all';

  /// "2026년 7월" → "7월" (필터 칩·그룹 헤더에서 재사용, 연도가 다른 동월은 v1에서 구분하지 않음).
  String _monthLabel(String month) => month.split(' ').last;

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(progressProvider).timeline;
    final questRepo = ref.watch(questRepositoryProvider);
    final regionRepo = ref.watch(regionRepositoryProvider);

    final monthLabels = <String>[];
    for (final entry in timeline) {
      final label = _monthLabel(entry.month);
      if (!monthLabels.contains(label)) monthLabels.add(label);
    }
    final filters = [
      const FilterChipOption(key: 'all', label: '전체'),
      for (final label in monthLabels)
        FilterChipOption(key: label, label: label),
    ];

    final filtered = _filter == 'all'
        ? timeline
        : timeline.where((e) => _monthLabel(e.month) == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('여행 타임라인'),
      ),
      body: Column(
        children: [
          if (timeline.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilterChipRow(
                options: filters,
                selectedKey: _filter,
                onSelected: (key) => setState(() => _filter = key),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      '아직 완료한 퀘스트가 없어요',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      for (var i = 0; i < filtered.length; i++) ...[
                        if (i == 0 ||
                            filtered[i].month != filtered[i - 1].month)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 12),
                            child: Text(
                              filtered[i].month,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        _TimelineRow(
                          entry: filtered[i],
                          isLast: i == filtered.length - 1,
                          questRepo: questRepo,
                          regionRepo: regionRepo,
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.isLast,
    required this.questRepo,
    required this.regionRepo,
  });

  final TimelineEntry entry;
  final QuestRepository questRepo;
  final RegionRepository regionRepo;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final quest = questRepo.byId(entry.questId);
    if (quest == null) return const SizedBox.shrink();
    final region = regionRepo.byId(quest.region);

    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: isLast
                          ? AppColors.timelineDotGrey
                          : AppColors.primaryDark,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: AppColors.timelineLine,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${region.name} · ${entry.date}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.timelineDateText,
                      ),
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
