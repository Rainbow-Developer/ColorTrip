import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/trip_card.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/trip_info_sheet.dart';
import '../../data/models/region.dart';
import '../../data/repositories/domain_repository.dart';
import '../../data/static/regions_data.dart';
import '../../state/domain_controller.dart';

/// 여행 목록 — 진행 중인 여행(여행 시작함, 선택한 퀘스트 중 미완료 있음) / 지난 여행(선택한 퀘스트 전부 완료)
/// ([Figma] 여행 목록 화면, 2026-07-09 "여행 시작하기" 도입으로 지역 진행도 기준에서 변경).
/// "여행" = 지역 하나에서 "여행 시작하기"로 담은 퀘스트 묶음으로 매핑한다.
class TravelListScreen extends ConsumerStatefulWidget {
  const TravelListScreen({super.key});

  @override
  ConsumerState<TravelListScreen> createState() => _TravelListScreenState();
}

class _TravelListScreenState extends ConsumerState<TravelListScreen> {
  String? _activeOperation;

  bool get _isOperating => _activeOperation != null;

  @override
  Widget build(BuildContext context) {
    final journeys =
        ref.watch(domainControllerProvider).value?.journeys ??
        const <DomainJourney>[];
    final inProgress = journeys
        .where((journey) => journey.status != 'completed')
        .toList();
    final past = journeys
        .where((journey) => journey.status == 'completed')
        .toList();

    final content = (inProgress.isEmpty && past.isEmpty)
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
    } on Object {
      if (mounted) {
        showAppToast(context, '여행 정보를 수정하지 못했어요. 다시 시도해주세요.');
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
