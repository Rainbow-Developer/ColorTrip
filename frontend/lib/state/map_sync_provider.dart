import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/static/regions_data.dart';
import 'progress_notifier.dart';
import 'repository_providers.dart';

/// 홈 화면 진입 시 서버 지도 진행도를 1회 동기화한다([020-frontend-map-sync]).
/// 로그인 전(토큰 없음)이거나 네트워크 오류면 조용히 실패하고 로컬 상태를 그대로 둔다 —
/// 로그인이 아직 스텁이라 "토큰 없음"이 정상 상태이기 때문이다.
final mapSyncProvider = FutureProvider.autoDispose<void>((ref) async {
  try {
    final items = await ref.read(mapRepositoryProvider).fetchMyMap();
    final serverRegionProgress = <String, int>{};
    for (final item in items) {
      final id = regionIdByName(item.regionName);
      if (id != null) {
        serverRegionProgress[id] = item.completedCount;
      }
    }
    ref
        .read(progressProvider.notifier)
        .syncRegionProgressFromServer(serverRegionProgress);
  } catch (error) {
    debugPrint('map sync skipped: $error');
  }
});
