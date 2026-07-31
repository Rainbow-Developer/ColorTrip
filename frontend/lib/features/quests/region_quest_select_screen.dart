import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/coach_mark.dart';
import '../../core/widgets/filter_chip_row.dart';
import '../../data/models/quest.dart';
import '../../data/static/regions_data.dart';
import '../../state/onboarding_tour_notifier.dart';
import '../../state/progress_notifier.dart';
import '../../state/progress_state.dart';
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

  /// 새 여행이면 이름·기간 입력 시트를 띄운 뒤 등록하고, 이미 시작한 여행이면
  /// 기존 이름·기간을 유지한 채 선택 퀘스트만 갱신한다.
  Future<void> _startTrip(String defaultName) async {
    final notifier = ref.read(progressProvider.notifier);
    final selected = {..._selectedQuestIds!};

    if (ref.read(progressProvider).tripStatusOf(widget.regionId) !=
        RegionTripStatus.notStarted) {
      notifier.setTripQuests(widget.regionId, selected);
      if (mounted) context.go('/travel');
      return;
    }

    final info = await showModalBottomSheet<TripInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _TripSetupSheet(defaultName: defaultName),
    );
    if (info == null || !mounted) return;

    notifier.startTrip(widget.regionId, selected, info);
    context.go('/travel');
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

    // 기존에 이 지역 여행에서 이미 고른 퀘스트가 있으면 그 상태로 시작한다(추가 선택 지원).
    final tripAlreadyStarted =
        progress.tripStatusOf(widget.regionId) != RegionTripStatus.notStarted;
    _selectedQuestIds ??= {...progress.tripQuestsOf(widget.regionId)};

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
                    return _SelectableQuestCard(
                      quest: quest,
                      regionName: region.name,
                      selected:
                          completed || _selectedQuestIds!.contains(quest.id),
                      locked: completed,
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
                  onPressed: selectedCount == 0
                      ? null
                      : () => _startTrip(tripTitleFor(region)),
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
    required this.locked,
    required this.onToggle,
    required this.onViewDetail,
  });

  final Quest quest;
  final String regionName;
  final bool selected;

  /// 이미 완료한 퀘스트 — 체크 해제할 수 없고, 탭하면 토글 대신 히스토리(퀘스트 상세)로 이동한다.
  final bool locked;
  final VoidCallback onToggle;
  final VoidCallback onViewDetail;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: locked ? onViewDetail : onToggle,
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
            SizedBox(
              width: 22,
              height: 22,
              child: Icon(
                locked
                    ? Icons.lock
                    : selected
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: selected
                    ? AppColors.primaryDark
                    : AppColors.timelineDotGrey,
                size: locked ? 18 : 22,
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
                      _MiniBadge(label: regionName),
                      const SizedBox(width: 4),
                      _MiniBadge(
                        label: questTypeStyles[quest.type]?.label ?? quest.type,
                      ),
                      if (locked) ...[
                        const SizedBox(width: 4),
                        const _MiniBadge(label: '완료됨'),
                      ],
                      const Spacer(),
                      GestureDetector(
                        onTap: onViewDetail,
                        child: Text(
                          locked ? '히스토리 보기' : '퀘스트 설명',
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
    );
  }
}

/// 여행 이름·기간 입력 시트 — 이름은 "OO 여행"이 기본값, 기간은 [showDateRangePicker]로
/// 시작일·종료일을 함께 받는다. 둘 다 채워야 시작할 수 있다.
class _TripSetupSheet extends StatefulWidget {
  const _TripSetupSheet({required this.defaultName});

  final String defaultName;

  @override
  State<_TripSetupSheet> createState() => _TripSetupSheetState();
}

class _TripSetupSheetState extends State<_TripSetupSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.defaultName,
  );
  DateTimeRange? _range;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, now.month, now.day),
      initialDateRange: _range,
      helpText: '여행 기간을 선택해주세요',
      saveText: '선택',
    );
    if (picked != null) setState(() => _range = picked);
  }

  InputDecoration _fieldDecoration({String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.formFieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.formFieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryDark),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final canSubmit = _nameController.text.trim().isNotEmpty && range != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '여행 정보를 입력해주세요',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          const Text(
            '여행 이름',
            style: TextStyle(fontSize: 12, color: AppColors.formLabel),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            maxLength: 30,
            onChanged: (_) => setState(() {}),
            decoration: _fieldDecoration(
              hintText: '예) 단양 여행',
            ).copyWith(counterText: ''),
          ),
          const SizedBox(height: 12),
          const Text(
            '여행 날짜',
            style: TextStyle(fontSize: 12, color: AppColors.formLabel),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickRange,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: _fieldDecoration(
                suffixIcon: const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
              child: Text(
                range == null
                    ? '시작일 ~ 종료일 선택'
                    : TripInfo.formatPeriod(range.start, range.end),
                style: TextStyle(
                  fontSize: 14,
                  color: range == null
                      ? AppColors.formPlaceholder
                      : AppColors.textStrong,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: canSubmit
                ? () => Navigator.pop(
                    context,
                    TripInfo(
                      name: _nameController.text.trim(),
                      startDate: range.start,
                      endDate: range.end,
                    ),
                  )
                : null,
            child: const Text('여행 시작하기'),
          ),
        ],
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
