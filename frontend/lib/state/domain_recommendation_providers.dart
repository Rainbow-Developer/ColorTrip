import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/domain_repository.dart';
import 'domain_controller.dart';
import 'repository_providers.dart';

/// 서버 상태가 바뀔 때마다 추천도 다시 가져온다.
final unvisitedRecommendedRegionsProvider =
    FutureProvider.autoDispose<List<DomainRecommendedRegion>>((ref) async {
      await ref.watch(domainControllerProvider.future);
      return ref
          .read(domainRepositoryProvider)
          .fetchUnvisitedRecommendedRegions();
    });

final recommendedQuestKeysProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, regionKey) async {
      await ref.watch(domainControllerProvider.future);
      return ref
          .read(domainRepositoryProvider)
          .fetchRecommendedQuestKeys(regionKey: regionKey);
    });
