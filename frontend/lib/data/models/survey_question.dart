/// 초기 설문(4문항). 각 선택지(`SurveyOption.dnaType`)가 여행 DNA 유형에 매핑된다.
class SurveyOption {
  const SurveyOption({required this.dnaType, required this.label});

  final String dnaType;
  final String label;
}

class SurveyQuestion {
  const SurveyQuestion({required this.question, required this.options});

  final String question;
  final List<SurveyOption> options;
}
