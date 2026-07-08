import 'package:flutter/material.dart';

import '../constants.dart';

class FilterChipOption {
  const FilterChipOption({required this.key, required this.label});

  final String key;
  final String label;
}

/// 가로 스크롤 필터 칩 목록 — 퀘스트 목록/타임라인 유형 필터에서 공통으로 쓰인다.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.options,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<FilterChipOption> options;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Chip(
                label: option.label,
                selected: option.key == selectedKey,
                onTap: () => onSelected(option.key),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF6A6A62),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
