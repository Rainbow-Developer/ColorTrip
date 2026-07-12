import '../models/quest.dart';
import '../static/quests_data.dart';

/// 퀘스트 조회 인터페이스. 백엔드 연동 시 Dio 기반 구현체로 교체한다([plan.md] 의사결정).
abstract class QuestRepository {
  List<Quest> all();
  List<Quest> byRegion(String regionId);
  List<Quest> byType(String type);
  Quest? byId(String id);
}

class StaticQuestRepository implements QuestRepository {
  const StaticQuestRepository();

  @override
  List<Quest> all() => kQuests;

  @override
  List<Quest> byRegion(String regionId) => questsByRegion(regionId);

  @override
  List<Quest> byType(String type) => questsByType(type);

  @override
  Quest? byId(String id) => questById(id);
}
