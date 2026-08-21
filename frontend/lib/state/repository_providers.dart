import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';
import '../data/location/location_gateway.dart';
import '../data/media/photo_picker_gateway.dart';
import '../data/repositories/auth_repository.dart';
import '../data/models/festival.dart';
import '../data/repositories/dna_repository.dart';
import '../data/repositories/festival_repository.dart';
import '../data/repositories/domain_repository.dart';
import '../data/repositories/map_repository.dart';
import '../data/repositories/place_repository.dart';
import '../data/repositories/quest_repository.dart';
import '../data/repositories/region_repository.dart';
import '../data/repositories/share_repository.dart';
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

final tripDnaRepositoryProvider = Provider<TripDnaRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiTripDnaRepository(dio);
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => DioAuthRepository(
    dio: ref.watch(dioProvider),
    kakao: ref.watch(kakaoAuthGatewayProvider),
    storage: ref.watch(secureTokenStorageProvider),
  ),
);

/// 지도 진행도(`GET /users/me/map`)는 실제로 백엔드를 호출한다([020-frontend-map-sync]).
final mapRepositoryProvider = Provider<MapRepository>(
  (ref) => DioMapRepository(ref.watch(dioProvider)),
);

final domainRepositoryProvider = Provider<DomainRepository>(
  (ref) => DioDomainRepository(ref.watch(dioProvider)),
);

final locationGatewayProvider = Provider<LocationGateway>(
  (ref) => const GeolocatorLocationGateway(),
);

final photoPickerGatewayProvider = Provider<PhotoPickerGateway>(
  (ref) => const ImagePickerPhotoPickerGateway(),
);

final shareRepositoryProvider = Provider<ShareRepository>(
  (ref) => DioShareRepository(ref.watch(dioProvider)),
);

/// TourAPI 장소 정보 실시간 프록시(docs/specs/090-realtime-tour-place-info).
final placeRepositoryProvider = Provider<PlaceRepository>(
  (ref) => DioPlaceRepository(ref.watch(dioProvider)),
);

/// 지역 행사·축제(docs/specs/095-festival-info) — 백엔드 프록시 전에는 시연용 스텁.
final festivalRepositoryProvider = Provider<FestivalRepository>(
  (ref) => const StubFestivalRepository(),
);

/// 지역별 행사·축제 상태 — 화면을 벗어나면 버린다(autoDispose, 090과 같은 패턴).
final regionFestivalsProvider = FutureProvider.autoDispose
    .family<List<Festival>, String>(
      (ref, regionId) =>
          ref.watch(festivalRepositoryProvider).byRegion(regionId),
    );
