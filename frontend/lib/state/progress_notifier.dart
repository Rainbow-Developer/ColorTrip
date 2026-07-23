import 'dart:typed_data';

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

  void setNickname(String nickname) {
    state = state.copyWith(nickname: nickname);
  }

  /// 퀘스트 선택 화면에서 "여행 시작하기"로 고른 최종 선택 결과로 지역의 여행을 갱신한다.
  /// 화면이 기존 선택 상태를 반영해 최종 Set을 넘기므로 합집합이 아니라 그대로 교체한다 —
  /// 합집합으로 병합하면 체크 해제로 뺀 퀘스트가 되살아나는 버그가 있었다(CodeRabbit 리뷰 반영).
  void setTripQuests(String regionId, Set<String> questIds) {
    final tripQuests = {...state.tripQuests};
    tripQuests[regionId] = {...questIds};
    state = state.copyWith(tripQuests: tripQuests);
  }

  /// 새 여행 시작 — 선택 퀘스트와 함께 이름·기간([TripInfo])을 등록한다.
  /// 이미 시작한 여행에 퀘스트를 더 담을 때는 [setTripQuests]만 호출해 기존 정보를 유지한다.
  void startTrip(String regionId, Set<String> questIds, TripInfo info) {
    final tripInfo = {...state.tripInfo};
    tripInfo[regionId] = info;
    state = state.copyWith(tripInfo: tripInfo);
    setTripQuests(regionId, questIds);
  }

  void completeQuest(String questId, {Uint8List? photo}) {
    final quest = questById(questId);
    if (quest == null || state.isCompleted(questId)) return;

    final completed = {...state.completedQuestIds, questId};

    // 서버 응답을 기다리지 않고 즉시 +1(낙관적 갱신) — 다음 동기화 때
    // syncRegionProgressFromServer가 실제 completed_count로 덮어쓴다.
    final progress = {...state.regionProgress};
    progress[quest.region] = (progress[quest.region] ?? 0) + 1;

    final entry = TimelineEntry(
      questId: questId,
      completedAt: DateTime.now(),
      photo: photo,
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

  /// 서버(`GET /users/me/map`) 진행도를 로컬 상태에 반영한다([020-frontend-map-sync]).
  /// 서버가 값을 준 지역만 덮어쓰고, 응답에 없는 지역은 기존 로컬 값을 유지한다.
  void syncRegionProgressFromServer(Map<String, int> serverRegionProgress) {
    if (serverRegionProgress.isEmpty) return;
    state = state.copyWith(
      regionProgress: {...state.regionProgress, ...serverRegionProgress},
    );
  }

  int totalReward() => kQuests
      .where((q) => state.isCompleted(q.id))
      .fold(0, (sum, q) => sum + q.reward);

  /// 회원 탈퇴 시 전역 진행 상태(완료 퀘스트·여행·DNA·닉네임 등)를 초기화한다.
  void reset() {
    state = const ProgressState.empty();
  }
}

final progressProvider = NotifierProvider<ProgressNotifier, ProgressState>(
  ProgressNotifier.new,
);
