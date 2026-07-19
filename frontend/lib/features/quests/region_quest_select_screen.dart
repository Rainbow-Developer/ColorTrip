import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/coach_mark.dart';
import '../../core/widgets/filter_chip_row.dart';
import '../../data/models/quest.dart';
import '../../state/onboarding_tour_notifier.dart';
import '../../state/progress_notifier.dart';
import '../../state/progress_state.dart';
import '../../state/repository_providers.dart';

/// 퀘스트 선택 — 지역 퀘스트를 여러 개 골라 "여행 시작하기"로 여행을 시작한다.
/// 여기서 고른 퀘스트는 그 자리에서 수행하는 게 아니라, 여행 탭의 "진행중인 여행"에 담기고
/// 나중에 지역 개요 화면에서 하나씩 수행한다(2026-07-09 사용자 확정).
/// 이미 여행을 시작(또는 완료)한 지역이면 기존 선택을 유지한 채 이어서 고르고, 버튼 문구도
/// "퀘스트 추가하기"로 바뀐다(KAN-46 — 완료된 지역도 재방문해 남은 퀘스트를 추가할 수 있다).
/// Figma 스펙(2026-07-09 공유) 반영: 검색·유형 필터, 카드별 "퀘스트 설명"으로 퀘스트 상세(정보만) 진입.
class RegionQuestSelectScreen extends ConsumerStatefulWidget {
  const RegionQuestSelectScreen({super.key, required this.regionId});

  final String regionId;

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    // 기존에 이 지역 여행에서 이미 고른 퀘스트가 있으면 그 상태로 시작한다(추가 선택 지원).
    final tripAlreadyStarted =
        ref.read(progressProvider).tripStatusOf(widget.regionId) !=
        RegionTripStatus.notStarted;
    _selectedQuestIds ??= {
      ...ref.read(progressProvider).tripQuestsOf(widget.regionId),
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
      appBar: AppBar(leading: const AppBackButton(), title: const Text('퀘스트')),
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
                    return _SelectableQuestCard(
                      quest: quest,
                      regionName: region.name,
                      selected: _selectedQuestIds!.contains(quest.id),
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
                  onPressed: selectedCount == 0
                      ? null
                      : () {
                          ref
                              .read(progressProvider.notifier)
                              .setTripQuests(
                                widget.regionId,
                                _selectedQuestIds!,
                              );
                          context.go('/travel');
                        },
                  child: Text(
                    selectedCount == 0
                        ? '퀘스트를 선택해주세요'
                        : tripAlreadyStarted
                        ? '퀘스트 추가하기 ($selectedCount)'
                        : '여행 시작하기 ($selectedCount)',
                  ),
                ),
              ),
            ],
          ),
          if (!tour.isDone && tour.step == 2)
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
    required this.regionName,
    required this.selected,
    required this.onToggle,
    required this.onViewDetail,
  });

  final Quest quest;
  final String regionName;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onViewDetail;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.questSelectedBg : Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected
                  ? AppColors.primaryDark
                  : AppColors.timelineDotGrey,
              size: 22,
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.imagePlaceholderBg,
                borderRadius: BorderRadius.circular(8),
              ),
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
                      _MiniBadge(label: regionName),
                      const SizedBox(width: 4),
                      _MiniBadge(
                        label: questTypeStyles[quest.type]?.label ?? quest.type,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onViewDetail,
                        child: const Text(
                          '퀘스트 설명',
                          style: TextStyle(
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
