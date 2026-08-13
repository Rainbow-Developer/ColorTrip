import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/domain_repository.dart';
import '../data/static/quests_data.dart';
import '../data/static/regions_data.dart';
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

    // 채색 집계는 "그 여행에서 완료한 퀘스트가 1개 이상인가"이므로(KAN-73), 이번 완료가
    // 그 지역 여행의 첫 완료인지를 이번 완료 **전** 상태로 판단한다.
    final trip = state.tripQuestsOf(quest.region);
    final hadCompletedQuestInTrip = trip.any(state.isCompleted);

    var next = state.copyWith(
      completedQuestIds: completed,
      regionProgress: progress,
      timeline: timeline,
    );

    // 첫 완료라면 로컬 채색 카운트를 1 올린다 ([055-journey-map-coloring]). 누적으로 두는
    // 이유: 완료한 지역에 퀘스트를 더 담아도(KAN-46 재방문) 이미 칠한 채색이 사라지지 않는다.
    if (trip.contains(questId) && !hadCompletedQuestInTrip) {
      final completions = {...next.localTripCompletions};
      completions[quest.region] = (completions[quest.region] ?? 0) + 1;
      next = next.copyWith(localTripCompletions: completions);
    }

    state = next;
  }

  /// 서버(`GET /users/me/map`) 진행도를 로컬 상태에 반영한다([020-frontend-map-sync]).
  /// 서버가 값을 준 지역만 덮어쓰고, 응답에 없는 지역은 기존 로컬 값을 유지한다.
  /// [serverRegionTripCount]는 지역별 완료 여행 수(completed_journey_count) — 지도 채색
  /// 기준이다([055-journey-map-coloring]). 로컬 파생값과의 max 병합은 저장 시점이 아니라
  /// 조회 시점([ProgressState.completedTripCountOf])에 하므로 여기서는 그대로 담는다.
  void syncRegionProgressFromServer(
    Map<String, int> serverRegionProgress, {
    Map<String, int> serverRegionTripCount = const {},
  }) {
    if (serverRegionProgress.isEmpty && serverRegionTripCount.isEmpty) return;
    state = state.copyWith(
      regionProgress: {...state.regionProgress, ...serverRegionProgress},
      regionTripCount: {...state.regionTripCount, ...serverRegionTripCount},
    );
  }

  /// 서버 스냅샷을 화면 호환 상태에 투영한다. 서버에 없는 과거 메모리 값은 유지하지 않는다.
  void replaceFromServer(DomainSnapshot snapshot) {
    final tripQuests = <String, Set<String>>{};
    final tripInfo = <String, TripInfo>{};
    for (final journey in snapshot.journeys) {
      if (tripQuests.containsKey(journey.regionKey)) continue;
      tripQuests[journey.regionKey] = journey.questKeys.toSet();
      if (journey.startDate != null && journey.endDate != null) {
        final region = regionById(journey.regionKey);
        tripInfo[journey.regionKey] = TripInfo(
          name: journey.title ?? (region == null ? '여행' : tripTitleFor(region)),
          startDate: journey.startDate!,
          endDate: journey.endDate!,
        );
      }
    }
    state = state.copyWith(
      completedQuestIds: {...snapshot.completedQuestKeys},
      timeline: [
        for (final entry in snapshot.timeline)
          TimelineEntry(
            questId: entry.questKey,
            completedAt: entry.occurredAt,
            photoUrl: entry.photoUrl,
          ),
      ],
      tripQuests: tripQuests,
      tripInfo: tripInfo,
      regionProgress: {...snapshot.regionProgress},
      // 지도 채색 기준([055-journey-map-coloring]) — 이 값이 비어 있으면 실제 퀘스트
      // 완료·여행 완주 흐름(DomainController.verifyQuest → refresh → replaceFromServer)에서
      // 지도가 영영 채색되지 않는 버그가 있었다. 서버 값이 로컬 누적([localTripCompletions])보다
      // 클 때만 의미가 있으므로(ProgressState.completedTripCountOf가 max 병합) 그대로 담는다.
      regionTripCount: {...snapshot.regionTripCount},
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
