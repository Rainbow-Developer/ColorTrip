import 'package:flutter/material.dart';

/// 여행 DNA 유형(5종) — 설문 결과로 진단된다.
class DnaType {
  const DnaType({
    required this.id,
    required this.name,
    required this.icon,
    required this.desc,
    required this.recommendation,
    required this.gradient,
    required this.tags,
  });

  final String id;
  final String name;
  final String icon;
  final String desc;
  final String recommendation;
  final List<Color> gradient;
  final List<String> tags;
}
