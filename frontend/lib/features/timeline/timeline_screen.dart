import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/chungbuk_map.dart';
import '../../core/widgets/quest_type_badge.dart' show MiniBadge;
import '../../data/models/region.dart';
import '../../data/repositories/domain_repository.dart';
import '../../data/repositories/quest_repository.dart';
import '../../data/repositories/region_repository.dart';
import '../../state/domain_controller.dart';
import '../../state/progress_notifier.dart';
import '../../state/progress_state.dart';
import '../../state/repository_providers.dart';

/// 여행 타임라인 — 완료 퀘스트를 지역별로 묶어 보여준다([080-timeline-journey-grouping]).
/// 연도 토글(‹ 2026년 ›) + 1~12월 pill(가로 슬라이드)로 월을 선택해 조회한다.
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  late int _year = DateTime.now().year;

  /// 선택된 월의 인덱스(0=1월 ~ 11=12월). null이면 현재 연도는 이번 달, 다른 연도는 1월을
  /// 기본으로 보여준다.
  int? _monthIndex;

  Future<void> _showPicker() async {
    final now = DateTime.now();
    int tempYear = _year;
    int tempMonth = _monthIndex ?? (tempYear == now.year ? now.month - 1 : 0);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: 300,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text(
                              '취소',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                          const Text(
                            '날짜 선택',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              '확인',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoPicker(
                              itemExtent: 40,
                              scrollController: FixedExtentScrollController(
                                initialItem: tempYear - 2024,
                              ),
                              onSelectedItemChanged: (idx) {
                                setSheetState(() {
                                  tempYear = 2024 + idx;
                                  if (tempYear == now.year &&
                                      tempMonth > now.month - 1) {
                                    tempMonth = now.month - 1;
                                  }
                                });
                              },
                              children: [
                                for (var y = 2024; y <= now.year; y++)
                                  Center(child: Text('$y년')),
                              ],
                            ),
                          ),
                          Expanded(
                            child: CupertinoPicker(
                              itemExtent: 40,
                              scrollController: FixedExtentScrollController(
                                initialItem: tempMonth,
                              ),
                              onSelectedItemChanged: (idx) {
                                setSheetState(() {
                                  tempMonth = idx;
                                  if (tempYear == now.year &&
                                      tempMonth > now.month - 1) {
                                    tempMonth = now.month - 1; // 미래 월 선택 제한
                                  }
                                });
                              },
                              children: [
                                for (var m = 1; m <= 12; m++)
                                  Center(
                                    child: Text(
                                      '$m월',
                                      style: TextStyle(
                                        color:
                                            (tempYear == now.year &&
                                                m > now.month)
                                            ? AppColors.textMuted
                                            : AppColors.textBody,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed == true) {
      final timeline = ref.read(progressProvider).timeline;
      final monthLabel = '$tempYear년 ${tempMonth + 1}월';
      final hasRecords = timeline.any((e) => e.month == monthLabel);

      if (!hasRecords) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '해당 월에는 여행 기록이 없습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.primaryDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }

      setState(() {
        _year = tempYear;
        _monthIndex = tempMonth;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final timeline = progress.timeline;
    final questRepo = ref.watch(questRepositoryProvider);
    final regionRepo = ref.watch(regionRepositoryProvider);
    final apiBaseUrl = ref.watch(appConfigProvider).apiBaseUrl;
    final journeys =
        ref.watch(domainControllerProvider).value?.journeys ??
        const <DomainJourney>[];

    final now = DateTime.now();
    final monthLabels = [for (var m = 1; m <= 12; m++) '$_year년 $m월'];
    final defaultIndex = _year == now.year ? now.month - 1 : 0;
    final idx = (_monthIndex ?? defaultIndex).clamp(0, 11);

    final filtered = timeline
        .where((e) => e.month == monthLabels[idx])
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('여행 타임라인'),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: InkWell(
              onTap: _showPicker,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_year년 ${idx + 1}월',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 24),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _RegionGroupedView(
              monthLabel: monthLabels[idx],
              filtered: filtered,
              journeys: journeys,
              questRepo: questRepo,
              regionRepo: regionRepo,
              apiBaseUrl: apiBaseUrl,
            ),
          ),
        ],
      ),
    );
  }
}

/// 지역별 보기 — 월 요약 카드 + 지역별 접기/펼치기 섹션.
class _RegionGroupedView extends StatelessWidget {
  const _RegionGroupedView({
    required this.monthLabel,
    required this.filtered,
    required this.journeys,
    required this.questRepo,
    required this.regionRepo,
    required this.apiBaseUrl,
  });

  final String monthLabel;
  final List<TimelineEntry> filtered;
  final List<DomainJourney> journeys;
  final QuestRepository questRepo;
  final RegionRepository regionRepo;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final groups = _groupByRegion(
      entries: filtered,
      journeys: journeys,
      questRepo: questRepo,
      regionRepo: regionRepo,
    );

    // 진행 바 분모는 그 달에 활동이 있었던 여행들의 questKeys 총합(퀘스트 수) 기준,
    // 분자는 이번 달에 실제 완료한 퀘스트 수(위 "M개 퀘스트"와 같은 기준)로 맞춘다.
    final touchedJourneyIds = <String>{};
    for (final entry in filtered) {
      for (final journey in journeys) {
        if (journey.questKeys.contains(entry.questId)) {
          touchedJourneyIds.add(journey.id);
        }
      }
    }
    final done = filtered.length;
    var total = 0;
    for (final journey in journeys) {
      if (!touchedJourneyIds.contains(journey.id)) continue;
      total += journey.questKeys.length;
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _MonthSummaryCard(
          monthLabel: monthLabel,
          regionCount: groups.length,
          completedQuestCount: filtered.length,
          done: done,
          total: total,
        ),
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                '아직 완료한 퀘스트가 없어요',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < groups.length; i++)
                  _RegionTimelineSection(
                    group: groups[i],
                    isLast: i == groups.length - 1,
                    questRepo: questRepo,
                    regionRepo: regionRepo,
                    apiBaseUrl: apiBaseUrl,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 완료 퀘스트를 지역 기준으로 묶은 그룹([080-timeline-journey-grouping] 지역별 보기).
class _RegionGroup {
  _RegionGroup({
    required this.region,
    required this.isActive,
    required this.isUpcoming,
  }) : entries = [];

  final Region region;

  /// 이 지역에 이미 시작된(오늘 &gt;= startDate) 진행중 여행이 있으면 true — "여행중" 표시에 쓴다.
  bool isActive;

  /// 이 지역에 아직 시작일이 안 된 여행이 있으면 true — "예정" 표시에 쓴다.
  bool isUpcoming;
  final List<TimelineEntry> entries;

  DateTime get earliestCompletedAt =>
      entries.map((e) => e.completedAt).reduce((a, b) => a.isBefore(b) ? a : b);
}

/// 월 필터링된 완료 퀘스트를 지역별로 묶고, 그룹 내 가장 이른 완료 시각 기준
/// 오름차순(과거 → 최근)으로 정렬한다.
List<_RegionGroup> _groupByRegion({
  required List<TimelineEntry> entries,
  required List<DomainJourney> journeys,
  required QuestRepository questRepo,
  required RegionRepository regionRepo,
}) {
  final now = DateTime.now();
  final groups = <String, _RegionGroup>{};
  for (final entry in entries) {
    final quest = questRepo.byId(entry.questId);
    if (quest == null) continue;
    final region = regionRepo.byId(quest.region);
    if (region == null) continue;

    final regionJourneys = journeys.where(
      (journey) =>
          journey.regionKey == quest.region && journey.status != 'completed',
    );
    // 시작일이 아직 안 된 여행은 "예정", 이미 시작된 여행은 "여행중"으로 구분한다.
    final isUpcoming = regionJourneys.any(
      (journey) => journey.startDate?.isAfter(now) ?? false,
    );
    final isActive = regionJourneys.any(
      (journey) => !(journey.startDate?.isAfter(now) ?? false),
    );
    final group = groups.putIfAbsent(
      quest.region,
      () => _RegionGroup(
        region: region,
        isActive: isActive,
        isUpcoming: isUpcoming,
      ),
    );
    if (isActive) group.isActive = true;
    if (isUpcoming) group.isUpcoming = true;
    group.entries.add(entry);
  }

  return groups.values.toList()
    ..sort((a, b) => a.earliestCompletedAt.compareTo(b.earliestCompletedAt));
}

/// 지역별 보기 상단의 월 요약 카드 — "{월}월의 여행 기록 / N개 지역 · M개 퀘스트" + 진행 바.
class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.monthLabel,
    required this.regionCount,
    required this.completedQuestCount,
    required this.done,
    required this.total,
  });

  final String monthLabel;
  final int regionCount;
  final int completedQuestCount;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'(\d+)월').firstMatch(monthLabel);
    final shortLabel = match != null ? '${match.group(1)}월' : monthLabel;
    final progress = total == 0 ? 0.0 : done / total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.tripActiveBadgeBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        size: 13,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$shortLabel의 여행 기록',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$regionCount개 지역 · $completedQuestCount개 퀘스트',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: AppColors.verifyProgressTrack,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$done/$total 완료',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 카드 왼쪽 여백(16)과 같은 간격을 텍스트-지도 사이에도 준다.
          const SizedBox(width: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            // 원본이 거의 정사각형이라 비율 그대로면 박스가 좁아 보인다. 가로로
            // 넓혀서(cover) 원본 상하의 빈 여백 위주로 잘리게 하고 좌우는 꽉 채운다.
            child: SizedBox(
              height: 94,
              width: 118,
              child: Image.asset(
                'assets/images/map_image.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 퀘스트 카드의 지역 배지에 쓰는 지역 팔레트 채도 — 5단계 중 3단계(부드러운 중간 톤)에
/// 대응한다([core/widgets/chungbuk_map.dart]의 mapFillColors, `_mapColorLevel`).

/// 지역 섹션 카드 배경에 쓰는 지역 팔레트 채도 — 5단계 중 가장 옅은 1단계.
const _regionSectionSaturation = 0.1;

/// 핀 아이콘·펼침 화살표·왼쪽 날짜 라벨("여행중"/"예정" 배지, 날짜 글자)에 쓰는
/// 지역 팔레트 채도 — 5단계 중 가장 진한 5단계.
const _regionAccentSaturation = 1.0;

/// 지역별 보기의 지역 1건 섹션 — 왼쪽 날짜 라벨 + 접기/펼치기 가능한 지역 카드.
/// 섹션끼리는 [isLast]가 아닌 한 점+선으로 이어져 하나의 타임라인처럼 보인다.
class _RegionTimelineSection extends StatelessWidget {
  const _RegionTimelineSection({
    required this.group,
    required this.isLast,
    required this.questRepo,
    required this.regionRepo,
    required this.apiBaseUrl,
  });

  final _RegionGroup group;
  final bool isLast;
  final QuestRepository questRepo;
  final RegionRepository regionRepo;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final date = group.earliestCompletedAt;
    final dateLabel = '${date.month}.${date.day.toString().padLeft(2, '0')}';
    final sectionColor = mapFillColors(
      group.region.id,
      _regionSectionSaturation,
    );
    final accentColor = mapFillColors(group.region.id, _regionAccentSaturation);
    final statusLabel = group.isUpcoming
        ? '예정'
        : group.isActive
        ? '여행중'
        : null;

    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 44,
              child: Stack(
                children: [
                  // 다음 지역 섹션까지 이어지는 세로선 — 점 바로 아래부터 시작한다.
                  if (!isLast)
                    Positioned(
                      left: 21.5,
                      top: 24,
                      bottom: 0,
                      child: Container(width: 1, color: AppColors.timelineLine),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accentColor.background,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: accentColor.background,
                          ),
                        ),
                        if (statusLabel != null) ...[
                          const SizedBox(height: 4),
                          MiniBadge(
                            label: statusLabel,
                            background: accentColor.background,
                            foreground: accentColor.label,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: sectionColor.background,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: Colors.transparent,
                    collapsedBackgroundColor: Colors.transparent,
                    iconColor: accentColor.background,
                    collapsedIconColor: accentColor.background,
                    leading: Icon(
                      Icons.location_on,
                      size: 18,
                      color: accentColor.background,
                    ),
                    title: Row(
                      children: [
                        Text(
                          group.region.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (group.isUpcoming) ...[
                          const SizedBox(width: 6),
                          Text(
                            '예정',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                        child: Column(
                          children: [
                            for (final entry in group.entries)
                              _TimelineRow(
                                entry: entry,
                                questRepo: questRepo,
                                regionRepo: regionRepo,
                                apiBaseUrl: apiBaseUrl,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 지역별 보기 섹션 안에 나열되는 완료 퀘스트 1건 — 정사각형 썸네일 + 제목/날짜/태그.
/// 이미 흰 카드(지역 섹션) 안에 있으므로 자체 카드 배경은 두지 않는다.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.questRepo,
    required this.regionRepo,
    required this.apiBaseUrl,
  });

  final TimelineEntry entry;
  final QuestRepository questRepo;
  final RegionRepository regionRepo;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final quest = questRepo.byId(entry.questId);
    if (quest == null) return const SizedBox.shrink();
    final typeStyle = questTypeStyles[quest.type];
    final tagColors = questTypeIconColors[quest.type];
    final photoUrl = entry.photoUrl;
    final resolvedPhotoUrl = photoUrl == null
        ? null
        : Uri.parse(apiBaseUrl).resolve(photoUrl).toString();
    // 인증에 실제로 쓴 사진(로컬 → 서버) → 없으면 퀘스트 관련 사진(TourAPI) → placeholder.
    final fallbackImage = AppNetworkImage(
      url: quest.imageUrl,
      placeholderEmoji: typeStyle?.emoji ?? '📍',
      placeholderEmojiSize: 22,
    );
    final thumbnail = entry.photo != null
        ? Image.memory(entry.photo!, fit: BoxFit.cover)
        : resolvedPhotoUrl != null
        ? Image.network(
            resolvedPhotoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallbackImage,
          )
        : fallbackImage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(width: 60, height: 60, child: thumbnail),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      quest.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.timelineDateText,
                      ),
                    ),
                    const SizedBox(height: 6),
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
              const SizedBox(width: 6),
              const Center(
                child: Icon(
                  Icons.check_circle,
                  size: 20,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
