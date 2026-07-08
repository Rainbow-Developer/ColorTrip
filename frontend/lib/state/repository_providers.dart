import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/dna_repository.dart';
import '../data/repositories/quest_repository.dart';
import '../data/repositories/region_repository.dart';
import '../data/repositories/survey_repository.dart';

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

final surveyRepositoryProvider = Provider<SurveyRepository>(
  (ref) => const StaticSurveyRepository(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const StubAuthRepository(),
);
