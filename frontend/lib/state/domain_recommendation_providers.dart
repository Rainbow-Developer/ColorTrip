import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/category_vocabulary.dart';
import '../data/repositories/domain_repository.dart';
import 'auth_controller.dart';
import 'domain_controller.dart';
import 'progress_notifier.dart';
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
      final progress = ref.watch(progressProvider);
      final user = ref.watch(currentUserProvider);
      var dnaType = toAppCategory(user?.dna ?? progress.dnaType ?? 'nature');
      const validCategories = [
        'nature',
        'food',
        'history',
        'activity',
        'healing',
      ];
      if (!validCategories.contains(dnaType)) {
        dnaType = 'nature';
      }

      return ref
          .read(domainRepositoryProvider)
          .fetchRecommendedQuestKeys(regionKey: regionKey, category: dnaType);
    });
