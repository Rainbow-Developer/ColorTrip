/// 지도 채색 기준(퀘스트를 1개 이상 완료한 여행 수) 검증
/// ([docs/specs/055-journey-map-coloring]).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colortrip/state/progress_notifier.dart';
import 'package:colortrip/state/progress_state.dart';

void main() {
  group('ProgressState.regionSaturation — 채색 집계 값 기반', () {
    test('집계 0회면 미채색(0.0)이고 완료 지역 통계도 0이다', () {
      const state = ProgressState.empty();
      expect(state.completedTripCountOf('cheongju'), 0);
      expect(state.regionSaturation('cheongju'), 0.0);
      expect(state.completedRegionCount, 0);
    });

    test('완료 여행 1회부터 채색이 시작되고(1/5) 완료 지역으로 센다', () {
      final state = const ProgressState.empty().copyWith(
        regionTripCount: {'cheongju': 1},
      );
      expect(state.regionSaturation('cheongju'), closeTo(1 / 5, 1e-9));
      expect(state.completedRegionCount, 1);
    });

    test('기준선(5회) 이상이면 최대 채도(1.0)로 고정된다', () {
      final state = const ProgressState.empty().copyWith(
        regionTripCount: {'cheongju': 5, 'danyang': 7},
      );
      expect(state.regionSaturation('cheongju'), 1.0);
      expect(state.regionSaturation('danyang'), 1.0);
      expect(state.completedRegionCount, 2);
    });

    test('서버 동기화 값이 로컬 완주 횟수보다 크면 서버 값을 쓴다(max 병합)', () {
      final state = const ProgressState.empty().copyWith(
        localTripCompletions: {'danyang': 1},
        regionTripCount: {'danyang': 2},
      );
      expect(state.completedTripCountOf('danyang'), 2);
      expect(state.regionSaturation('danyang'), closeTo(2 / 5, 1e-9));
    });

    test('채색은 집계 값으로만 결정되고 완료 퀘스트 집합에서 파생하지 않는다', () {
      // 완료 퀘스트가 있어도 집계 값(로컬 누적·서버 동기화)이 없으면 0이다 — 집계는
      // completeQuest·서버 응답에서만 올라간다.
      final state = const ProgressState.empty().copyWith(
        tripQuests: {
          'danyang': {'dy1', 'dy2'},
        },
        completedQuestIds: {'dy1'},
      );
      expect(state.tripStatusOf('danyang'), RegionTripStatus.inProgress);
      expect(state.completedTripCountOf('danyang'), 0);
      expect(state.regionSaturation('danyang'), 0.0);
    });

    test('완료 퀘스트 개수(regionProgress)는 더 이상 채색에 영향을 주지 않는다', () {
      final state = const ProgressState.empty().copyWith(
        regionProgress: {'cheongju': 6},
      );
      expect(state.regionSaturation('cheongju'), 0.0);
      expect(state.completedRegionCount, 0);
    });
  });

  group('ProgressNotifier.completeQuest — 로컬 채색 카운트', () {
    /// 단양 여행을 [questIds]로 시작한 컨테이너.
    ProviderContainer startDanyangTrip(Set<String> questIds) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(progressProvider.notifier)
          .setTripQuests('danyang', questIds);
      return container;
    }

    test('여행 퀘스트를 1개 완료하면 서버 값이 없어도 1회로 계산된다', () {
      final container = startDanyangTrip({'dy1'});
      container.read(progressProvider.notifier).completeQuest('dy1');

      final state = container.read(progressProvider);
      expect(state.localTripCompletions['danyang'], 1);
      expect(state.completedTripCountOf('danyang'), 1);
      expect(state.regionSaturation('danyang'), closeTo(1 / 5, 1e-9));
      expect(state.completedRegionCount, 1);
    });

    test('퀘스트 5개를 담고 1개만 완료해도 그 여행이 1회로 집계된다 (KAN-73)', () {
      // 사용자 요구: 여행에 퀘스트가 5개 있어도 1개라도 완료하면 지도가 칠해져야 한다.
      final container = startDanyangTrip({'dy1', 'dy2', 'dy3', 'dy4', 'dy5'});
      container.read(progressProvider.notifier).completeQuest('dy1');

      final state = container.read(progressProvider);
      expect(state.tripStatusOf('danyang'), RegionTripStatus.inProgress);
      expect(state.completedTripCountOf('danyang'), 1);
      expect(state.regionSaturation('danyang'), closeTo(1 / 5, 1e-9));
      expect(state.completedRegionCount, 1);
    });

    test('같은 여행에서 퀘스트를 더 완료해도 집계는 여행 단위로 1회다 (KAN-73)', () {
      final container = startDanyangTrip({'dy1', 'dy2'});
      final notifier = container.read(progressProvider.notifier);
      notifier.completeQuest('dy1');
      notifier.completeQuest('dy2');

      final state = container.read(progressProvider);
      expect(state.tripStatusOf('danyang'), RegionTripStatus.completed);
      expect(state.completedTripCountOf('danyang'), 1);
      expect(state.regionSaturation('danyang'), closeTo(1 / 5, 1e-9));
    });

    test('완료한 지역에 퀘스트를 더 담아도 이미 칠한 채색이 사라지지 않는다', () {
      // KAN-46 재방문 흐름 — "퀘스트 더 선택하기"로 선택 집합이 교체돼 현재 집합이 다시
      // 미완료가 되어도, 누적한 채색 카운트는 유지되어야 한다.
      final container = startDanyangTrip({'dy1'});
      final notifier = container.read(progressProvider.notifier);
      notifier.completeQuest('dy1');
      notifier.setTripQuests('danyang', {'dy1', 'dy2'});

      final afterAdd = container.read(progressProvider);
      expect(afterAdd.tripStatusOf('danyang'), RegionTripStatus.inProgress);
      expect(afterAdd.completedTripCountOf('danyang'), 1);
      expect(afterAdd.regionSaturation('danyang'), closeTo(1 / 5, 1e-9));
      expect(afterAdd.completedRegionCount, 1);
    });

    test('여행을 시작하지 않은 채 완료한 퀘스트는 채색에 세지 않는다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(progressProvider.notifier).completeQuest('dy1');

      final state = container.read(progressProvider);
      expect(state.tripStatusOf('danyang'), RegionTripStatus.notStarted);
      expect(state.completedTripCountOf('danyang'), 0);
      expect(state.regionSaturation('danyang'), 0.0);
    });
  });

  group('ProgressNotifier.syncRegionProgressFromServer — 여행 수 동기화', () {
    test('퀘스트 수와 여행 수를 함께 반영하고, 응답에 없는 지역은 유지한다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(progressProvider.notifier);

      notifier.syncRegionProgressFromServer(
        {'cheongju': 4},
        serverRegionTripCount: {'cheongju': 2},
      );
      notifier.syncRegionProgressFromServer(
        {'danyang': 1},
        serverRegionTripCount: {'danyang': 1},
      );

      final state = container.read(progressProvider);
      expect(state.regionProgress['cheongju'], 4);
      expect(state.regionTripCount['cheongju'], 2);
      expect(state.regionTripCount['danyang'], 1);
      expect(state.regionSaturation('cheongju'), closeTo(2 / 5, 1e-9));
      expect(state.completedRegionCount, 2);
    });
  });
}
