import '../models/dna_type.dart';
import '../static/dna_data.dart';

/// 여행 DNA 조회 인터페이스. 백엔드 연동 시 Dio 기반 구현체로 교체한다([plan.md] 의사결정).
abstract class DnaRepository {
  DnaType byId(String id);
}

class StaticDnaRepository implements DnaRepository {
  const StaticDnaRepository();

  @override
  DnaType byId(String id) => dnaTypeById(id);
}
