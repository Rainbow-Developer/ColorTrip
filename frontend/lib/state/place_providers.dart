import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/place_detail.dart';
import 'repository_providers.dart';

/// 지역 관광지 이미지 맵(contentId → URL) — 화면 진입 시 실시간 조회하고,
/// 화면을 벗어나면 버린다(autoDispose — 저장·캐싱하지 않는 090 스펙 결정).
/// 실패 시 화면은 placeholder를 그대로 쓴다.
final regionPlaceImagesProvider = FutureProvider.autoDispose
    .family<Map<String, String>, String>(
      (ref, regionId) =>
          ref.watch(placeRepositoryProvider).regionImages(regionId),
    );

/// 장소 상세(이미지·소개문·운영정보) 실시간 조회 — 키는 (contentId, contentTypeId).
final placeDetailProvider = FutureProvider.autoDispose
    .family<PlaceDetail, ({String contentId, String contentTypeId})>(
      (ref, key) => ref
          .watch(placeRepositoryProvider)
          .detail(key.contentId, key.contentTypeId),
    );
