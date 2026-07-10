import '../models/region.dart';
import '../static/regions_data.dart';

/// 지역(시·군) 조회 인터페이스. 백엔드 연동 시 Dio 기반 구현체로 교체한다([plan.md] 의사결정).
abstract class RegionRepository {
  List<Region> all();

  /// id에 해당하는 지역, 없으면 null(잘못되거나 오래된 링크 대비).
  Region? byId(String id);
}

class StaticRegionRepository implements RegionRepository {
  const StaticRegionRepository();

  @override
  List<Region> all() => kRegionsInMapOrder;

  @override
  Region? byId(String id) => regionById(id);
}
