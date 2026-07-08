import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/static/quests_data.dart';
import 'progress_state.dart';

/// 앱 전역 진행 상태 Notifier — 퀘스트 완료·DNA 진단 시 상태를 갱신한다.
class ProgressNotifier extends Notifier<ProgressState> {
  @override
  ProgressState build() => const ProgressState.empty();

  void setDnaType(String dnaType) {
    state = state.copyWith(dnaType: dnaType);
  }

  /// 퀘스트 선택 화면에서 "여행 시작하기"로 고른 퀘스트를 지역의 여행에 추가한다.
  /// 기존에 골라둔 퀘스트가 있으면 합쳐진다(여행 추가 선택).
  void startTrip(String regionId, Set<String> questIds) {
    final tripQuests = {...state.tripQuests};
    tripQuests[regionId] = {...(tripQuests[regionId] ?? const {}), ...questIds};
    state = state.copyWith(tripQuests: tripQuests);
  }

  void completeQuest(String questId, {required int month}) {
    final quest = questById(questId);
    if (quest == null || state.isCompleted(questId)) return;

    final completed = {...state.completedQuestIds, questId};
    final progress = {...state.regionProgress};
    progress[quest.region] = (progress[quest.region] ?? 0) + 1;

    final entry = TimelineEntry(
      questId: questId,
      date: '2026.0$month.15',
      month: '2026년 $month월',
    );
    final timeline = [
      entry,
      ...state.timeline.where((t) => t.questId != questId),
    ];

    state = state.copyWith(
      completedQuestIds: completed,
      regionProgress: progress,
      timeline: timeline,
    );
  }

  int totalReward() => kQuests
      .where((q) => state.isCompleted(q.id))
      .fold(0, (sum, q) => sum + q.reward);
}

final progressProvider = NotifierProvider<ProgressNotifier, ProgressState>(
  ProgressNotifier.new,
);
