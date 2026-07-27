/// 디자인 토큰 — 프로토타입(docs/specs/000-frontend-app/prototype/prototype.dc.html)에서 그대로 옮김.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primaryDark = Color(0xFF2D6A4F);
  static const primaryLight = Color(0xFF97C459);
  static const textStrong = Color(0xFF1F1F1B);
  static const textHeading = Color(0xFF16331F);
  static const textMuted = Color(0xFF9A9A90);
  static const textBody = Color(0xFF4A4A44);
  static const border = Color(0xFFE6E6DF);
  static const surfaceMuted = Color(0xFFF5F5F0);
  static const background = Color(0xFFFAFAF7);
  static const danger = Color(0xFFE24B4A);
  // 지도 색칠 — 미방문 지역은 회색, 방문한 지역은 지역별 팔레트(regionMapColors)를
  // 5단계로 양자화해서 쓴다(KAN-51).
  static const mapEmpty = Color(0xFFCCCCCC);
  static const mapEmptyLabel = Color(0xFF9A9A90);

  // 스플래시(Figma) — color-spring-green-* / color-yellow-50 토큰.
  static const splashCardBackground = Color(0xFFE8EFE4);
  static const splashHeading = Color(0xFF2E5A47);
  static const splashAccent = Color(0xFF4A7C5F);
  static const kakaoYellow = Color(0xFFFEE500);
  static const kakaoLabel = Color(0xFF191919);

  // 여행 목록(Figma) — 진행 중 카드는 지역 배지에 강조색, 지난 카드는 전부 무채색.
  static const tripActiveBadgeBg = Color(0xFFEAF3DE);
  static const tripActiveBadgeFg = Color(0xFF1A5C35);
  static const tripMutedBadgeBg = Color(0xFFF0F0EA);
  static const tripMutedBadgeFg = Color(0xFF888888);
  static const tripProgressText = Color(0xFF444444);

  // 회원가입 폼(Figma) — 비어있는 필드는 크림/연회색, 값이 있는 필드는 흰 배경+초록 테두리.
  static const formFieldBg = Color(0xFFF8F8F4);
  static const formFieldBorder = Color(0xFFE4E4DE);
  static const formPlaceholder = Color(0xFFBBBBBB);
  static const formLabel = Color(0xFF999999);
  static const checkboxBorder = Color(0xFFDDDDDD);

  // 여행 타임라인(Figma) — 타임라인 점/선, 날짜 텍스트.
  static const timelineDotGrey = Color(0xFFCCCCCC);
  static const timelineLine = Color(0xFFEEEEEE);
  static const timelineDateText = Color(0xFFC0C0BA);

  // 퀘스트 상세(Figma) — 인증방식 배지(파랑 계열), 관광지 이미지 placeholder.
  static const verifyBadgeBg = Color(0xFFE6F1FB);
  static const verifyBadgeFg = Color(0xFF0C447C);
  static const imagePlaceholderBg = Color(0xFFEBEBEB);

  // 사진/GPS 인증 화면(Figma) — 업로드 박스, 지도 미리보기, 진행 바.
  static const uploadBoxBg = Color(0xFFF8F8F4);
  static const uploadBoxBorder = Color(0xFFCCCCCC);
  static const verifyMapBg = Color(0xFFF0F0EA);
  static const verifyProgressTrack = Color(0xFFEEEEEA);

  // 공유 카드 만들기(Figma) — 지도 미리보기 카드 배경/텍스트.
  static const shareMapPreviewBg = Color(0xFFE0EDD8);
  static const shareMapPreviewText = Color(0xFF7AAA6A);

  // 퀘스트 선택(Figma) — 선택된 퀘스트 카드 배경.
  static const questSelectedBg = Color(0xFFC8E2C0);
}

/// 퀘스트 유형 색상/이모지 — TYPE 상수(prototype.dc.html) 대응.
class QuestTypeStyle {
  const QuestTypeStyle({
    required this.label,
    required this.background,
    required this.foreground,
    required this.emoji,
  });

  final String label;
  final Color background;
  final Color foreground;
  final String emoji;
}

const questTypeStyles = <String, QuestTypeStyle>{
  'nature': QuestTypeStyle(
    label: '자연탐험',
    background: Color(0xFFE6F1E8),
    foreground: Color(0xFF2D6A4F),
    emoji: '🌲',
  ),
  'food': QuestTypeStyle(
    label: '미식방문',
    background: Color(0xFFFBEAE0),
    foreground: Color(0xFFC2622E),
    emoji: '🍜',
  ),
  'history': QuestTypeStyle(
    label: '역사문화',
    background: Color(0xFFECE9F4),
    foreground: Color(0xFF5B4A9E),
    emoji: '🏛️',
  ),
  'active': QuestTypeStyle(
    label: '액티비티',
    background: Color(0xFFE6EEF7),
    foreground: Color(0xFF3A6BB0),
    emoji: '🧗',
  ),
  'healing': QuestTypeStyle(
    label: '힐링',
    background: Color(0xFFEAF3E4),
    foreground: Color(0xFF5C8A3A),
    emoji: '☕',
  ),
};

const verifyLabels = <String, String>{
  'photo': '사진 인증',
  'gps': 'GPS 인증',
  'quiz': 'OX 퀴즈',
};

/// 지역별 5단계 채색 팔레트(연함→진함) — 디자인 시안 색상표 그대로,
/// [core/widgets/chungbuk_map.dart]의 mapFillColors가 채도 레벨(1~5)에 맞춰 고른다(KAN-51).
const Map<String, List<Color>> regionMapColors = {
  'jincheon': [
    Color(0xFFF8F3F2),
    Color(0xFFF2E5E3),
    Color(0xFFEDD4CF),
    Color(0xFFE8BEB5),
    Color(0xFFE3A396),
  ],
  'eumseong': [
    Color(0xFFF8F6F2),
    Color(0xFFF2EEE3),
    Color(0xFFEDE4CF),
    Color(0xFFE8D9B5),
    Color(0xFFE3CC96),
  ],
  'chungju': [
    Color(0xFFF2F8F4),
    Color(0xFFE3F2E9),
    Color(0xFFCFEDDB),
    Color(0xFFB5E8CA),
    Color(0xFF96E3B6),
  ],
  'jecheon': [
    Color(0xFFF8F5F2),
    Color(0xFFF2EAE3),
    Color(0xFFEDDDCF),
    Color(0xFFE8CDB5),
    Color(0xFFE3BA96),
  ],
  'danyang': [
    Color(0xFFF4F2F8),
    Color(0xFFE8E3F2),
    Color(0xFFD9CFED),
    Color(0xFFC6B5E8),
    Color(0xFFB096E3),
  ],
  'jeungpyeong': [
    Color(0xFFF6F8F2),
    Color(0xFFEDF2E3),
    Color(0xFFE2EDCF),
    Color(0xFFD5E8B5),
    Color(0xFFC7E396),
  ],
  'cheongju': [
    Color(0xFFF4F8F2),
    Color(0xFFE9F2E3),
    Color(0xFFDBEDCF),
    Color(0xFFCAE8B5),
    Color(0xFFB6E396),
  ],
  'goesan': [
    Color(0xFFF2F8F6),
    Color(0xFFE3F2EE),
    Color(0xFFCFEDE5),
    Color(0xFFB5E8DB),
    Color(0xFF96E3D0),
  ],
  'boeun': [
    Color(0xFFF8F5F2),
    Color(0xFFF2EBE3),
    Color(0xFFEDDFCF),
    Color(0xFFE8D1B5),
    Color(0xFFE3C196),
  ],
  'okcheon': [
    Color(0xFFF8F2F5),
    Color(0xFFF2E3EB),
    Color(0xFFEDCFDF),
    Color(0xFFE8B5D0),
    Color(0xFFE396BF),
  ],
  'yeongdong': [
    Color(0xFFF8F7F2),
    Color(0xFFF2F0E3),
    Color(0xFFEDE8CF),
    Color(0xFFE8DFB5),
    Color(0xFFE3D696),
  ],
};

/// 지도 범례([core/widgets/map_legend.dart]) 5단계 스와치 — 실제 지역 팔레트는 지역마다
/// hue가 달라 대표색으로 못 쓰므로, 앱 기존 파스텔 그린 톤(splashCardBackground·
/// questSelectedBg 계열)에 맞춘 별도 그라데이션을 쓴다(KAN-51).
const List<Color> mapLegendColors = [
  Color(0xFFEAF3E4),
  Color(0xFFD2E7C6),
  Color(0xFFB6D9A8),
  Color(0xFF98CB8B),
  Color(0xFF78BC6E),
];
