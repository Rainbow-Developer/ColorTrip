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
  static const background = Color(0xFFFAFAFA);
  static const danger = Color(0xFFE24B4A);
  // 지도 색칠 — 미방문 지역은 연한 회색, 방문한 지역은 지역별 팔레트(regionMapColors)를
  // 5단계로 양자화해서 쓴다(KAN-51). 지역 경계선은 기존 미방문 회색(mapLine)을 그대로 쓴다.
  static const mapLine = Color(0xFFCCCCCC);
  static const mapEmpty = Color(0xFFF0F0F0);
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

  // 인증 진행 중 화면을 덮는 스크림(KAN-73) — 뒤 화면을 어둡게 눌러 진행 중임을 알린다.
  static const verifyScrim = Color(0xB3333333);

  // 공유 카드 만들기(Figma) — 지도 미리보기 카드 배경.
  static const shareMapPreviewBg = Color(0xFFE0EDD8);

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
  'activity': QuestTypeStyle(
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

/// 퀘스트 유형 태그 배색 — 원형 아이콘([quest_type_*.svg])에 쓴 연한 배경/선 색 그대로.
/// 퀘스트 목록·여행 목록 카드에서 공용으로 쓴다.
const questTypeIconColors = <String, ({Color background, Color foreground})>{
  'nature': (background: Color(0xFFE8F5E9), foreground: Color(0xFF43A047)),
  'food': (background: Color(0xFFFFF3E0), foreground: Color(0xFFFB8C00)),
  'history': (background: Color(0xFFEDE7F6), foreground: Color(0xFF7E57C2)),
  'activity': (background: Color(0xFFE3F2FD), foreground: Color(0xFF1E88E5)),
  'healing': (background: Color(0xFFFCE4EC), foreground: Color(0xFFD81B60)),
};

/// 퀘스트 유형 아이콘 이미지 — 퀘스트 목록의 카테고리 선택, 여행 DNA 결과 카드에서 공용으로 쓴다.
const questTypeIconAssets = <String, String>{
  'nature': 'assets/images/quest_type_nature.svg',
  'food': 'assets/images/quest_type_food.svg',
  'history': 'assets/images/quest_type_history.svg',
  'activity': 'assets/images/quest_type_active.svg',
  'healing': 'assets/images/quest_type_healing.svg',
};

/// 여행 DNA 카드(여행하기 화면) 왼쪽의 유형 아이콘 일러스트 — dna_data.dart 유형 id에
/// 대응한다. 'healing' 유형만 파일명이 'relax'로 되어 있다.
const dnaCardIconAssets = <String, String>{
  'nature': 'assets/images/icon_nature.png',
  'food': 'assets/images/icon_food.png',
  'history': 'assets/images/icon_history.png',
  'activity': 'assets/images/icon_activity.png',
  'healing': 'assets/images/icon_relax.png',
};

/// 퀘스트/여행 목록 카드 고정 높이 — 값을 바꾸면 카드·좌측 썸네일(4:3) 크기가 같이 바뀐다.
const double questCardHeight = 100;

const verifyLabels = <String, String>{
  'photo': '사진 인증',
  'gps': 'GPS 인증',
  'quiz': 'OX 퀴즈',
  'qr': 'QR 인증',
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
