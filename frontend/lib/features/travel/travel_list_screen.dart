import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/network/api_error_message.dart';
import '../../core/widgets/trip_card.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/trip_info_sheet.dart';
import '../../data/models/region.dart';
import '../../data/repositories/domain_repository.dart';
import '../../data/static/regions_data.dart';
import '../../state/domain_controller.dart';

/// 여행 목록 — 진행중/진행 예정/지난 여행을 날짜와 서버 status 기준으로 나눈다.
/// "여행" = 지역 하나에서 "여행 시작하기"로 담은 퀘스트 묶음으로 매핑한다.
class TravelListScreen extends ConsumerStatefulWidget {
  const TravelListScreen({super.key});

  @override
  ConsumerState<TravelListScreen> createState() => _TravelListScreenState();
}

class _TravelListScreenState extends ConsumerState<TravelListScreen> {
  String? _activeOperation;
  bool _upcomingExpanded = false;
  bool _pastExpanded = false;

  bool get _isOperating => _activeOperation != null;

  @override
  Widget build(BuildContext context) {
    final journeys =
        ref.watch(domainControllerProvider).value?.journeys ??
        const <DomainJourney>[];
    final today = _dateOnly(DateTime.now());
    final inProgress = journeys
        .where(
          (journey) =>
              _travelListSectionOf(journey, today) ==
              _TravelListSection.inProgress,
        )
        .toList();
    final upcoming =
        journeys
            .where(
              (journey) =>
                  _travelListSectionOf(journey, today) ==
                  _TravelListSection.upcoming,
            )
            .toList()
          ..sort(_compareByStartDateAscending);
    final past =
        journeys
            .where(
              (journey) =>
                  _travelListSectionOf(journey, today) ==
                  _TravelListSection.past,
            )
            .toList()
          ..sort(_compareByEndDateDescending);

    final content = (inProgress.isEmpty && upcoming.isEmpty && past.isEmpty)
        ? const Center(
            child: Text(
              '아직 시작한 여행이 없어요.\n홈 지도에서 지역을 골라 퀘스트를 시작해보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          )
        : ListView(
            // 명시 padding은 스크롤뷰의 자동 하단 인셋을 없앤다 — 떠 있는 하단탭
            // (extendBody) 높이가 담긴 MediaQuery 하단 패딩을 직접 더해 마지막
            // 카드가 탭바에 깔리지 않게 한다.
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              if (inProgress.isNotEmpty) ...[
                const _SectionHeader('진행중인 여행'),
                for (final journey in inProgress)
                  _journeyCard(journey, isActive: true),
                const SizedBox(height: 12),
              ],
              if (upcoming.isNotEmpty) ...[
                _CollapsibleSectionHeader(
                  label: '진행 예정인 여행',
                  count: upcoming.length,
                  expanded: _upcomingExpanded,
                  onTap: () =>
                      setState(() => _upcomingExpanded = !_upcomingExpanded),
                ),
                if (_upcomingExpanded)
                  for (final journey in upcoming)
                    _journeyCard(journey, isActive: true),
                const SizedBox(height: 12),
              ],
              if (past.isNotEmpty) ...[
                _CollapsibleSectionHeader(
                  label: '지난 여행',
                  count: past.length,
                  expanded: _pastExpanded,
                  onTap: () => setState(() => _pastExpanded = !_pastExpanded),
                ),
                if (_pastExpanded)
                  for (final journey in past)
                    _journeyCard(journey, isActive: false),
              ],
            ],
          );

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
      body: Stack(
        children: [
          content,
          if (_isOperating)
            ModalBarrier(
              dismissible: false,
              color: Colors.black.withValues(alpha: 0.08),
            ),
          if (_isOperating) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _journeyCard(DomainJourney journey, {required bool isActive}) {
    final region = regionByStableKey(journey.regionKey);
    if (region == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('여행 지역 정보를 불러오지 못했어요.'),
      );
    }
    return TripCard(
      key: ValueKey(journey.id),
      journey: journey,
      region: region,
      isActive: isActive,
      onTap: () => context.push('/journey/${journey.id}'),
      onEdit: isActive && !_isOperating
          ? () => _editJourney(journey, region)
          : null,
      onDelete: !_isOperating ? () => _deleteJourney(journey) : null,
    );
  }

  Future<void> _editJourney(DomainJourney journey, Region region) async {
    final startDate = journey.startDate;
    final endDate = journey.endDate;
    final info = await showTripInfoSheet(
      context: context,
      initialName: journey.title ?? tripTitleFor(region),
      initialRange: startDate == null || endDate == null
          ? null
          : DateTimeRange(start: startDate, end: endDate),
      title: '여행 정보를 수정해주세요',
      submitLabel: '저장하기',
    );
    if (info == null || !mounted) return;

    setState(() => _activeOperation = 'edit:${journey.id}');
    try {
      await ref
          .read(domainControllerProvider.notifier)
          .updateJourney(
            journeyId: journey.id,
            title: info.name,
            startDate: info.startDate,
            endDate: info.endDate,
          );
      if (mounted) showAppToast(context, '여행 정보를 수정했어요.');
    } on Object catch (error) {
      if (mounted) {
        showAppToast(
          context,
          apiErrorMessage(error, '여행 정보를 수정하지 못했어요. 다시 시도해주세요.'),
        );
      }
    } finally {
      if (mounted) setState(() => _activeOperation = null);
    }
  }

  Future<void> _deleteJourney(DomainJourney journey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('여행을 삭제할까요?'),
        content: const Text(
          '이 여행만 사용 중인 퀘스트 진행 기록은 삭제돼요. 같은 퀘스트를 담은 다른 여행이 있으면 완료 기록은 그 여행에 유지됩니다. 삭제한 여행은 복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _activeOperation = 'delete:${journey.id}');
    try {
      await ref
          .read(domainControllerProvider.notifier)
          .deleteJourney(journeyId: journey.id);
      if (mounted) showAppToast(context, '여행을 삭제했어요.');
    } on Object {
      if (mounted) {
        showAppToast(context, '여행을 삭제하지 못했어요. 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _activeOperation = null);
    }
  }
}

enum _TravelListSection { inProgress, upcoming, past }

_TravelListSection _travelListSectionOf(DomainJourney journey, DateTime today) {
  if (journey.status == 'completed') return _TravelListSection.past;
  final startDate = journey.startDate;
  if (startDate != null && _dateOnly(startDate).isAfter(today)) {
    return _TravelListSection.upcoming;
  }
  return _TravelListSection.inProgress;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _compareByStartDateAscending(DomainJourney a, DomainJourney b) {
  final startCompare = _compareNullableDateAscending(a.startDate, b.startDate);
  if (startCompare != 0) return startCompare;
  return b.createdAt.compareTo(a.createdAt);
}

int _compareByEndDateDescending(DomainJourney a, DomainJourney b) {
  final endCompare = _compareNullableDateAscending(b.endDate, a.endDate);
  if (endCompare != 0) return endCompare;
  return b.createdAt.compareTo(a.createdAt);
}

int _compareNullableDateAscending(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return _dateOnly(a).compareTo(_dateOnly(b));
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

class _CollapsibleSectionHeader extends StatelessWidget {
  const _CollapsibleSectionHeader({
    required this.label,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
