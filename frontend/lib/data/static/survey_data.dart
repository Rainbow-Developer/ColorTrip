/// 초기 설문(4문항) 정적 데이터 — 프로토타입(SURVEY 상수)에서 그대로 옮김.
/// 최다 선택 유형이 여행 DNA로 집계된다([state/onboarding_state.dart] 참고).
library;

import '../models/survey_question.dart';

const List<SurveyQuestion> kSurveyQuestions = [
  SurveyQuestion(
    question: '여행에서 가장 중요한 것은 무엇인가요?',
    options: [
      SurveyOption(dnaType: 'nature', label: '자연 속에서의 힐링과 휴식'),
      SurveyOption(dnaType: 'food', label: '현지 맛집 탐방과 미식 경험'),
      SurveyOption(dnaType: 'history', label: '역사·문화 유적지 탐방'),
      SurveyOption(dnaType: 'active', label: '액티비티와 모험적인 경험'),
      SurveyOption(dnaType: 'healing', label: '한적한 곳에서의 여유로운 시간'),
    ],
  ),
  SurveyQuestion(
    question: '여행 사진첩에 제일 많은 사진은?',
    options: [
      SurveyOption(dnaType: 'nature', label: '풍경과 하늘'),
      SurveyOption(dnaType: 'food', label: '음식과 카페'),
      SurveyOption(dnaType: 'history', label: '건축물과 유물'),
      SurveyOption(dnaType: 'active', label: '활동하는 순간'),
      SurveyOption(dnaType: 'healing', label: '감성 가득한 일상컷'),
    ],
  ),
  SurveyQuestion(
    question: '충북에서 하루가 주어진다면?',
    options: [
      SurveyOption(dnaType: 'nature', label: '호수와 산을 트레킹'),
      SurveyOption(dnaType: 'food', label: '로컬 맛집 투어'),
      SurveyOption(dnaType: 'history', label: '박물관과 사찰 탐방'),
      SurveyOption(dnaType: 'active', label: '케이블카와 짚라인'),
      SurveyOption(dnaType: 'healing', label: '한적한 카페에서 멍'),
    ],
  ),
  SurveyQuestion(
    question: '당신의 여행 페이스는?',
    options: [
      SurveyOption(dnaType: 'nature', label: '발길 닿는 대로 탐험'),
      SurveyOption(dnaType: 'food', label: '맛집 동선 위주로'),
      SurveyOption(dnaType: 'history', label: '미리 공부하고 깊이 있게'),
      SurveyOption(dnaType: 'active', label: '빽빽하고 알차게'),
      SurveyOption(dnaType: 'healing', label: '느긋하게 천천히'),
    ],
  ),
];
