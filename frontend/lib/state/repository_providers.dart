import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/dna_repository.dart';
import '../data/repositories/map_repository.dart';
import '../data/repositories/quest_repository.dart';
import '../data/repositories/region_repository.dart';
import '../data/repositories/trip_dna_repository.dart';

/// Repository seam — 백엔드 연동 시 이 Provider들의 override만 교체하면 된다([plan.md] 의사결정).
final questRepositoryProvider = Provider<QuestRepository>(
  (ref) => const StaticQuestRepository(),
);

final regionRepositoryProvider = Provider<RegionRepository>(
  (ref) => const StaticRegionRepository(),
);

final dnaRepositoryProvider = Provider<DnaRepository>(
  (ref) => const StaticDnaRepository(),
);

final tripDnaRepositoryProvider = Provider<TripDnaRepository>(
  (ref) {
    final dio = ref.watch(dioProvider);
    return ApiTripDnaRepository(dio);
  },
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const StubAuthRepository(),
);

/// 지도 진행도(`GET /users/me/map`)는 실제로 백엔드를 호출한다([020-frontend-map-sync]).
final mapRepositoryProvider = Provider<MapRepository>(
  (ref) => DioMapRepository(ref.watch(dioProvider)),
);
