import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/coach_mark.dart';
import '../../core/widgets/filter_chip_row.dart';
import '../../core/widgets/trip_info_sheet.dart';
import '../../data/models/quest.dart';
import '../../data/repositories/domain_repository.dart';
import '../../data/static/regions_data.dart';
import '../../state/onboarding_tour_notifier.dart';
import '../../state/domain_controller.dart';
import '../../state/progress_notifier.dart';
import '../../state/repository_providers.dart';

/// 퀘스트 선택 — 지역 퀘스트를 여러 개 골라 "여행 시작하기"로 여행을 시작한다.
/// 여기서 고른 퀘스트는 그 자리에서 수행하는 게 아니라, 여행 탭의 "진행중인 여행"에 담기고
/// 나중에 지역 개요 화면에서 하나씩 수행한다(2026-07-09 사용자 확정).
/// 이미 여행을 시작(또는 완료)한 지역이면 기존 선택을 유지한 채 이어서 고르고, 버튼 문구도
/// "퀘스트 추가하기"로 바뀐다(KAN-46 — 완료된 지역도 재방문해 남은 퀘스트를 추가할 수 있다).
/// 이미 완료한 퀘스트는 체크 해제할 수 없다(잠금) — 완료 기록은 히스토리로 남아야 하고,
/// 체크 해제로 조용히 지워지면 안 된다(KAN-46 피드백). 대신 카드를 탭하면 퀘스트 상세(완료 표시
/// 포함)로 이동해 히스토리를 확인할 수 있다.
/// Figma 스펙(2026-07-09 공유) 반영: 검색·유형 필터, 카드별 "퀘스트 설명"으로 퀘스트 상세(정보만) 진입.
/// 새 여행이면 시작 전에 이름·기간 입력 시트를 거친다(2026-07-16 KAN-28).
class RegionQuestSelectScreen extends ConsumerStatefulWidget {
  const RegionQuestSelectScreen({
    super.key,
    required this.regionId,
    this.journeyId,
  });

  final String regionId;
  final String? journeyId;

  @override
  ConsumerState<RegionQuestSelectScreen> createState() =>
      _RegionQuestSelectScreenState();
}

class _RegionQuestSelectScreenState
    extends ConsumerState<RegionQuestSelectScreen> {
  final _searchController = TextEditingController();
  final _startTripButtonKey = GlobalKey();
  String _typeFilter = 'all';
  Set<String>? _selectedQuestIds;
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 새 여행이면 이름·기간 입력 시트를 띄운 뒤 등록하고, 이미 시작한 여행이면
  /// 기존 이름·기간을 유지한 채 선택 퀘스트만 갱신한다.
  Future<void> _startTrip(String defaultName, OnboardingTourState tour) async {
    if (_saving) return;
    final selected = {..._selectedQuestIds!};
    final journeys =
        ref.read(domainControllerProvider).value?.journeys ??
        const <DomainJourney>[];
    final existingJourney = widget.journeyId == null
        ? null
        : journeys
              .where((journey) => journey.id == widget.journeyId)
              .firstOrNull;

    if (existingJourney != null) {
      setState(() => _saving = true);
      try {
        await ref
            .read(domainControllerProvider.notifier)
            .replaceJourneyQuests(
              journeyId: existingJourney.id,
              questKeys: selected.toList(),
            );
        _advanceTourAfterSuccessfulSave(tour);
        if (mounted) context.go('/travel');
      } on Object {
        if (mounted) {
          showAppToast(context, '퀘스트 선택을 저장하지 못했어요. 다시 시도해주세요.');
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    final info = await showTripInfoSheet(
      context: context,
      initialName: defaultName,
      title: '여행 정보를 입력해주세요',
      submitLabel: '여행 시작하기',
    );
    if (info == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(domainControllerProvider.notifier)
          .createJourney(
            regionKey: widget.regionId,
            questKeys: selected.toList(),
            title: info.name,
            startDate: info.startDate,
            endDate: info.endDate,
          );
      _advanceTourAfterSuccessfulSave(tour);
      if (mounted) context.go('/travel');
    } on Object {
      if (mounted) {
        showAppToast(context, '여행을 저장하지 못했어요. 네트워크를 확인해주세요.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _advanceTourAfterSuccessfulSave(OnboardingTourState tour) {
    if (!tour.isDone && tour.step == 2) {
      ref.read(onboardingTourProvider.notifier).advance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final region = ref.watch(regionRepositoryProvider).byId(widget.regionId);
    if (region == null) {
      return const Scaffold(body: Center(child: Text('지역을 찾을 수 없어요')));
    }
    final allRegionQuests = ref
        .watch(questRepositoryProvider)
        .byRegion(widget.regionId);

    final progress = ref.watch(progressProvider);
    final journeys =
        ref.watch(domainControllerProvider).value?.journeys ??
        const <DomainJourney>[];
    final selectedJourney = widget.journeyId == null
        ? null
        : journeys
              .where((journey) => journey.id == widget.journeyId)
              .firstOrNull;

    final inProgressJourneys = journeys.where((j) =>
        j.regionKey == widget.regionId &&
        j.status != 'completed' &&
        j.id != widget.journeyId);
    final questsInOtherJourneys =
        inProgressJourneys.expand((j) => j.questKeys).toSet();

    // 기존에 이 지역 여행에서 이미 고른 퀘스트가 있으면 그 상태로 시작한다(추가 선택 지원).
    final tripAlreadyStarted = selectedJourney != null;
    _selectedQuestIds ??= {
      ...(selectedJourney?.questKeys ?? const <String>{}),
    };

    final availableTypes = <String>{for (final q in allRegionQuests) q.type};
    final filters = [
      const FilterChipOption(key: 'all', label: '전체'),
      for (final type in availableTypes)
        FilterChipOption(
          key: type,
          label: questTypeStyles[type]?.label ?? type,
        ),
    ];

    final query = _searchController.text.trim();
    final quests = allRegionQuests.where((q) {
      final matchesType = _typeFilter == 'all' || q.type == _typeFilter;
      final matchesQuery = query.isEmpty || q.title.contains(query);
      return matchesType && matchesQuery;
    }).toList();

    final selectedCount = _selectedQuestIds!.length;
    final tour = ref.watch(onboardingTourProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('퀘스트'),
        titleSpacing: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '퀘스트 검색',
                    suffixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textMuted,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.primaryDark,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: FilterChipRow(
                  options: filters,
                  selectedKey: _typeFilter,
                  onSelected: (key) => setState(() => _typeFilter = key),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: quests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final quest = quests[index];
                    final completed = progress.isCompleted(quest.id);
                    final inOtherJourney = questsInOtherJourneys.contains(quest.id);
                    return _SelectableQuestCard(
                      quest: quest,
                      selected: _selectedQuestIds!.contains(quest.id),
                      completed: completed,
                      badgeLabel: completed ? '완료됨' : (inOtherJourney ? '진행중' : null),
                      onToggle: () => setState(() {
                        if (!_selectedQuestIds!.add(quest.id)) {
                          _selectedQuestIds!.remove(quest.id);
                        }
                      }),
                      onViewDetail: () => context.push('/quest/${quest.id}'),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ElevatedButton(
                  key: _startTripButtonKey,
                  // 새 여행이면 이름·기간 입력 시트(KAN-28), 이미 시작한 여행이면
                  // 시트 없이 퀘스트만 추가(KAN-46) — 분기는 _startTrip이 담당.
                  onPressed: selectedCount == 0 || _saving
                      ? null
                      : () => _startTrip(tripTitleFor(region), tour),
                  child: Text(
                    _saving
                        ? '저장 중...'
                        : selectedCount == 0
                        ? '퀘스트를 선택해주세요'
                        : tripAlreadyStarted
                        ? '퀘스트 추가하기 ($selectedCount)'
                        : '여행 시작하기 ($selectedCount)',
                  ),
                ),
              ),
            ],
          ),
          if (!tour.isDone && tour.step == 2 && selectedCount > 0)
            CoachMarkOverlay(
              targetKey: _startTripButtonKey,
              stepIndex: 2,
              title: '여행을 시작해보세요',
              body:
                  '퀘스트를 고른 뒤 "여행 시작하기"를 누르면\n'
                  '나만의 여행이 시작돼요.',
            ),
        ],
      ),
    );
  }
}

class _SelectableQuestCard extends StatelessWidget {
  const _SelectableQuestCard({
    required this.quest,
    required this.selected,
    required this.completed,
    this.badgeLabel,
    required this.onToggle,
    required this.onViewDetail,
  });

  final Quest quest;
  final bool selected;
  final bool completed;
  final String? badgeLabel;
  final VoidCallback onToggle;
  final VoidCallback onViewDetail;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.questSelectedBg : Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (badgeLabel != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 6,
                child: Container(
                  color: badgeLabel == '완료됨'
                      ? AppColors.primaryDark
                      : Colors.orange[400],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(badgeLabel != null ? 14 : 10, 10, 10, 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? AppColors.primaryDark : AppColors.timelineDotGrey,
                      size: 22,
                    ),
                  ),
            const SizedBox(width: 8),
            AppNetworkImage(
              url: quest.imageUrl,
              width: 44,
              height: 44,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (verifyLabels[quest.verify] != null) ...[
                        _MiniBadge(label: verifyLabels[quest.verify]!),
                        const SizedBox(width: 4),
                      ],
                      _MiniBadge(
                        label: questTypeStyles[quest.type]?.label ?? quest.type,
                      ),
                      if (badgeLabel != null) ...[
                        const SizedBox(width: 4),
                        _MiniBadge(label: badgeLabel!),
                      ],
                      const Spacer(),
                      GestureDetector(
                        onTap: onViewDetail,
                        child: Text(
                          completed ? '히스토리 보기' : '퀘스트 설명',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.tripMutedBadgeFg,
                          ),
                        ),
                      ),
                    ],
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
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tripMutedBadgeBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppColors.tripMutedBadgeFg),
      ),
    );
  }
}
