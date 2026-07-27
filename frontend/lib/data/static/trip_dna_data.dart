/// 초기 설문(4문항) 정적 데이터 — 프로토타입(SURVEY 상수)에서 그대로 옮김.
library;

import '../models/trip_dna_question.dart';

const List<TripDnaQuestion> kTripDnaQuestions = [
  TripDnaQuestion(
    id: 'q1',
    question: '여행에서 가장 중요한 것은 무엇인가요?',
    options: [
      TripDnaOption(id: 'q1_o1', dnaType: 'nature', label: '자연 속에서의 힐링과 휴식'),
      TripDnaOption(id: 'q1_o2', dnaType: 'food', label: '현지 맛집 탐방과 미식 경험'),
      TripDnaOption(id: 'q1_o3', dnaType: 'history', label: '역사·문화 유적지 탐방'),
      TripDnaOption(id: 'q1_o4', dnaType: 'activity', label: '액티비티와 모험적인 경험'),
      TripDnaOption(id: 'q1_o5', dnaType: 'healing', label: '한적한 곳에서의 여유로운 시간'),
    ],
  ),
  TripDnaQuestion(
    id: 'q2',
    question: '여행 사진첩에 제일 많은 사진은?',
    options: [
      TripDnaOption(id: 'q2_o1', dnaType: 'nature', label: '풍경과 하늘'),
      TripDnaOption(id: 'q2_o2', dnaType: 'food', label: '음식과 카페'),
      TripDnaOption(id: 'q2_o3', dnaType: 'history', label: '건축물과 유물'),
      TripDnaOption(id: 'q2_o4', dnaType: 'activity', label: '활동하는 순간'),
      TripDnaOption(id: 'q2_o5', dnaType: 'healing', label: '감성 가득한 일상컷'),
    ],
  ),
  TripDnaQuestion(
    id: 'q3',
    question: '충북에서 하루가 주어진다면?',
    options: [
      TripDnaOption(id: 'q3_o1', dnaType: 'nature', label: '호수와 산을 트레킹'),
      TripDnaOption(id: 'q3_o2', dnaType: 'food', label: '로컬 맛집 투어'),
      TripDnaOption(id: 'q3_o3', dnaType: 'history', label: '박물관과 사찰 탐방'),
      TripDnaOption(id: 'q3_o4', dnaType: 'activity', label: '케이블카와 짚라인'),
      TripDnaOption(id: 'q3_o5', dnaType: 'healing', label: '한적한 카페에서 멍'),
    ],
  ),
  TripDnaQuestion(
    id: 'q4',
    question: '당신의 여행 페이스는?',
    options: [
      TripDnaOption(id: 'q4_o1', dnaType: 'nature', label: '발길 닿는 대로 탐험'),
      TripDnaOption(id: 'q4_o2', dnaType: 'food', label: '맛집 동선 위주로'),
      TripDnaOption(id: 'q4_o3', dnaType: 'history', label: '미리 공부하고 깊이 있게'),
      TripDnaOption(id: 'q4_o4', dnaType: 'activity', label: '빽빽하고 알차게'),
      TripDnaOption(id: 'q4_o5', dnaType: 'healing', label: '느긋하게 천천히'),
    ],
  ),
];
