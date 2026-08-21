/// 퀘스트에 반경이 지정되지 않았을 때 쓰는 위치 인증 반경(m).
///
/// 위치 판정은 단말에서 수행되므로(좌표 비전송) **이 값이 실제 적용되는 반경**이다.
const kDefaultVerifyRadiusMeters = 500;

/// 퀘스트. `verify`는 photo/gps/quiz/qr 중 하나([core/constants.dart]의 verifyLabels 대응).
class Quest {
  const Quest({
    required this.id,
    required this.region,
    required this.type,
    required this.title,
    required this.place,
    required this.verify,
    required this.reward,
    required this.conditions,
    this.desc,
    this.quizQuestion,
    this.quizAnswer,
    this.tourContentId,
    this.tourContentTypeId,
    this.lat,
    this.lng,
    this.verifyRadius,
  });

  final String id;
  final String region;
  final String type;
  final String title;
  final String place;
  final String verify;
  final int reward;

  /// 수제 퀘스트의 직접 쓴 설명. 생성 퀘스트는 null — 소개문을 TourAPI에서
  /// 실시간 조회해 표시한다(docs/specs/090-realtime-tour-place-info).
  final String? desc;

  final List<String> conditions;
  final String? quizQuestion;
  final bool? quizAnswer;

  /// TourAPI contentId — 이미지·소개문·운영정보 실시간 조회의 키
  /// (docs/specs/090-realtime-tour-place-info). null이면 placeholder 표시.
  final String? tourContentId;

  /// TourAPI contentTypeId (12 관광지·14 문화시설·28 레포츠·39 음식점).
  final String? tourContentTypeId;

  /// 퀘스트 장소 좌표 — 위치 인증의 온디바이스 거리 계산에만 사용한다
  /// (docs/specs/050-quest-verification, 좌표는 서버로 전송하지 않는다).
  final double? lat;
  final double? lng;

  /// 위치 인증 반경(m). null이면 [kDefaultVerifyRadiusMeters]를 쓴다.
  final int? verifyRadius;

  bool get isQuiz => verify == 'quiz';
}
