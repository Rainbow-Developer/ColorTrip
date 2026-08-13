import 'package:flutter/material.dart';

import '../constants.dart';

/// 퀘스트 유형 배지 — 목록/상세 화면에서 공통으로 쓰인다.
class QuestTypeBadge extends StatelessWidget {
  const QuestTypeBadge({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final style = questTypeStyles[type];
    if (style == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          color: style.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 인증 방식 배지(사진/GPS/OX퀴즈) — [core/constants.dart]의 verifyLabels 대응.
/// 파란 계열 배색은 퀘스트 상세 화면 Figma 스펙(2026-07-08)을 따른다.
class VerifyBadge extends StatelessWidget {
  const VerifyBadge({super.key, required this.verify});

  final String verify;

  @override
  Widget build(BuildContext context) {
    final label = verifyLabels[verify] ?? verify;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.verifyBadgeBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.verifyBadgeFg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 배경·글자색을 직접 지정하는 작은 배지 — 여행하기 화면의 지역/유형 태그,
/// 타임라인 카드의 지역 태그(지역별 고유 팔레트, [core/widgets/chungbuk_map.dart]의
/// mapFillColors)에서 공유한다.
class MiniBadge extends StatelessWidget {
  const MiniBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: foreground)),
    );
  }
}

/// 지역 배지 — 여행 목록의 진행중 배지와 같은 배색(초록)을 공유한다.
class RegionBadge extends StatelessWidget {
  const RegionBadge({super.key, required this.regionName});

  final String regionName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.tripActiveBadgeBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        regionName,
        style: const TextStyle(
          color: AppColors.tripActiveBadgeFg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
