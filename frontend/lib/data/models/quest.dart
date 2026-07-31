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
    required this.desc,
    required this.conditions,
    this.quizQuestion,
    this.quizAnswer,
    this.imageUrl,
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
  final String desc;
  final List<String> conditions;
  final String? quizQuestion;
  final bool? quizAnswer;

  /// TourAPI 대표 이미지(firstimage) URL — 없으면 placeholder 표시
  /// (docs/specs/045-quest-region-images).
  final String? imageUrl;

  /// 퀘스트 장소 좌표 — 위치 인증의 온디바이스 거리 계산에만 사용한다
  /// (docs/specs/050-quest-verification, 좌표는 서버로 전송하지 않는다).
  final double? lat;
  final double? lng;

  /// 위치 인증 반경(m). null이면 기본값(500m)을 쓴다.
  final int? verifyRadius;

  bool get isQuiz => verify == 'quiz';
}
