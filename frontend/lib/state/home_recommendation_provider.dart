import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';
import '../data/models/home_recommendation.dart';
import '../data/repositories/home_repository.dart';

/// 홈 추천(`GET /home/recommendation`)은 실제로 백엔드를 호출한다
/// ([040-home-region-recommendation]).
///
/// 주의: repository seam은 원래 [state/repository_providers.dart]에 모으지만, 이 provider는
/// 병렬 작업 충돌을 피해 여기 함께 둔다 — 후속 정리 시 그쪽으로 옮겨도 된다.
final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => DioHomeRepository(ref.watch(dioProvider)),
);

/// 홈 DNA 지역 추천 — API 성공 시 추천 데이터를, dio 예외(비로그인·서버 미가동)나 지역
/// 매핑 실패 시 null을 돌려줘 배너가 기존 정적 계산으로 폴백하게 한다
/// ([040-home-region-recommendation] 의사결정 — FE는 정적 우선 아키텍처라 서버 없이도
/// 홈이 깨지면 안 된다). 로그인이 아직 스텁이라 "토큰 없음"이 정상 상태인 것은
/// [map_sync_provider]와 같다.
final homeRecommendationProvider =
    FutureProvider.autoDispose<HomeRecommendation?>((ref) async {
      try {
        return await ref.read(homeRepositoryProvider).fetchRecommendation();
      } catch (error) {
        debugPrint('home recommendation fallback: $error');
        return null;
      }
    });
