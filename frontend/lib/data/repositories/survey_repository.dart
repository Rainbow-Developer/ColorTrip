import '../models/survey_question.dart';
import '../static/survey_data.dart';

/// 초기 설문 조회 인터페이스. 백엔드 연동 시 Dio 기반 구현체로 교체한다([plan.md] 의사결정).
abstract class SurveyRepository {
  List<SurveyQuestion> questions();
}

class StaticSurveyRepository implements SurveyRepository {
  const StaticSurveyRepository();

  @override
  List<SurveyQuestion> questions() => kSurveyQuestions;
}
