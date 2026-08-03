import '../static/regions_data.dart';
import 'category_vocabulary.dart';

/// `GET /home/recommendation` 응답의 대표 퀘스트 요약 1건(표시 전용,
/// [040-home-region-recommendation]). BE 퀘스트 id는 UUID라 FE 정적 id와 체계가 달라
/// 개별 딥링크에 쓸 수 없으므로 담지 않는다 — 배너 탭 이동은 지역 단위로만 한다.
class HomeRecommendedQuest {
  const HomeRecommendedQuest({
    required this.title,
    required this.category,
    required this.missionType,
    this.thumbnailUrl,
  });

  factory HomeRecommendedQuest.fromJson(Map<String, dynamic> json) {
    return HomeRecommendedQuest(
      title: json['title'] as String,
      // 서버 어휘(activity) → 앱 어휘(active) 변환 후 담는다([toAppCategory]).
      category: toAppCategory(json['category'] as String),
      missionType: json['mission_type'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }

  final String title;

  /// 퀘스트 유형(nature/food/... — [core/constants.dart]의 questTypeStyles 키와 동일 체계).
  final String category;

  final String missionType;
  final String? thumbnailUrl;
}

/// 홈 DNA 지역 추천(`GET /home/recommendation`) 응답 — 추천 지역 + 대표 퀘스트 요약
/// 최대 3개([040-home-region-recommendation]).
class HomeRecommendation {
  const HomeRecommendation({
    required this.regionId,
    required this.regionName,
    required this.imageUrl,
    required this.dnaCategory,
    required this.quests,
  });

  /// BE region.name(예: "청주시")을 로컬 지역 id로 변환해 파싱한다(map_sync와 동일하게
  /// [regionIdByName] 사용). FE 정적 지도에 없는 지역이면 null — 잘못된 추천으로 배너를
  /// 그리는 대신 호출부가 정적 폴백으로 처리하게 한다. (factory 생성자는 null을 돌려줄 수
  /// 없어 static 메서드로 둔다.)
  static HomeRecommendation? fromJson(Map<String, dynamic> json) {
    final region = json['region'] as Map<String, dynamic>;
    final regionName = region['name'] as String;
    final regionId = regionIdByName(regionName);
    if (regionId == null) return null;

    return HomeRecommendation(
      regionId: regionId,
      regionName: regionName,
      imageUrl: region['image_url'] as String?,
      dnaCategory: toAppCategory(json['dna_category'] as String),
      quests: [
        for (final quest in (json['quests'] as List? ?? const []))
          HomeRecommendedQuest.fromJson(quest as Map<String, dynamic>),
      ],
    );
  }

  /// 로컬 지역 id(예: 'cheongju') — 배너 탭 시 `/region/{id}` 이동에 쓴다.
  final String regionId;

  final String regionName;

  /// 지역 대표 이미지(썸네일 보유 퀘스트에서 BE가 대표 1건을 골라 채움) — 없으면 null.
  final String? imageUrl;

  /// 추천 산출에 쓰인 DNA 카테고리(미판정 사용자는 BE가 기본 nature로 내려준다).
  final String dnaCategory;

  final List<HomeRecommendedQuest> quests;
}
