/// 초기 설문(4문항). 각 선택지가 여행 DNA 유형에 매핑된다.
class TripDnaOption {
  const TripDnaOption({required this.id, required this.label, this.dnaType});

  final String id;
  final String label;
  final String? dnaType; // Mock 데이터용 카테고리 정보 (API 응답에서는 제외됨)

  factory TripDnaOption.fromJson(Map<String, dynamic> json) {
    return TripDnaOption(
      id: json['id'] as String,
      label: json['content'] as String,
    );
  }
}

class TripDnaQuestion {
  const TripDnaQuestion({
    required this.id,
    required this.question,
    required this.options,
  });

  final String id;
  final String question;
  final List<TripDnaOption> options;

  factory TripDnaQuestion.fromJson(Map<String, dynamic> json) {
    final optionsList = (json['options'] as List<dynamic>)
        .map((opt) => TripDnaOption.fromJson(opt as Map<String, dynamic>))
        .toList();
    return TripDnaQuestion(
      id: json['id'] as String,
      question: json['question'] as String,
      options: optionsList,
    );
  }
}
