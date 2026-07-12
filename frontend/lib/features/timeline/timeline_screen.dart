import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../data/repositories/quest_repository.dart';
import '../../data/repositories/region_repository.dart';
import '../../state/progress_notifier.dart';
import '../../state/progress_state.dart';
import '../../state/repository_providers.dart';

/// 여행 타임라인 — 월별 필터 칩 대신 캘린더형 "‹ 2026년 7월 ›" 네비게이터로 한 달씩 이동하며 조회.
/// 점+선으로 이어지는 타임라인 카드(마지막 항목만 회색 점).
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  /// 선택된 월의 인덱스(monthLabels 기준). null이면 가장 최근 달을 기본으로 보여준다.
  int? _monthIndex;

  /// "2026년 7월" → 정렬용 정수(202607). 형식이 어긋나면 0으로 취급한다.
  int _monthSortKey(String month) {
    final match = RegExp(r'(\d+)년 (\d+)월').firstMatch(month);
    if (match == null) return 0;
    final year = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    return year * 100 + m;
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(progressProvider).timeline;
    final questRepo = ref.watch(questRepositoryProvider);
    final regionRepo = ref.watch(regionRepositoryProvider);

    final monthLabels = <String>[];
    for (final entry in timeline) {
      if (!monthLabels.contains(entry.month)) monthLabels.add(entry.month);
    }
    monthLabels.sort((a, b) => _monthSortKey(a).compareTo(_monthSortKey(b)));

    final idx = monthLabels.isEmpty
        ? 0
        : (_monthIndex ?? monthLabels.length - 1).clamp(
            0,
            monthLabels.length - 1,
          );

    final filtered = monthLabels.isEmpty
        ? const <TimelineEntry>[]
        : timeline.where((e) => e.month == monthLabels[idx]).toList();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('여행 타임라인'),
      ),
      body: Column(
        children: [
          if (monthLabels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _MonthNavigator(
                label: monthLabels[idx],
                canGoPrev: idx > 0,
                canGoNext: idx < monthLabels.length - 1,
                onPrev: () => setState(() => _monthIndex = idx - 1),
                onNext: () => setState(() => _monthIndex = idx + 1),
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
                      for (var i = 0; i < filtered.length; i++)
                        _TimelineRow(
                          entry: filtered[i],
                          isLast: i == filtered.length - 1,
                          questRepo: questRepo,
                          regionRepo: regionRepo,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// "‹ 2026년 7월 ›" 형태의 캘린더형 월 이동 네비게이터.
class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.label,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MonthNavButton(
          icon: Icons.chevron_left,
          enabled: canGoPrev,
          onTap: onPrev,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        _MonthNavButton(
          icon: Icons.chevron_right,
          enabled: canGoNext,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppColors.primaryDark : AppColors.checkboxBorder,
          ),
        ),
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
                      '${region?.name ?? quest.region} · ${entry.date}',
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
