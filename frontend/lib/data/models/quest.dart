/// 퀘스트. `verify`는 photo/gps/quiz 중 하나([core/constants.dart]의 verifyLabels 대응).
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

  bool get isQuiz => verify == 'quiz';
}
