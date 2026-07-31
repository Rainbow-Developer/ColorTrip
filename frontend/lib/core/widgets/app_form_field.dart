import 'package:flutter/material.dart';

import '../constants.dart';

/// 라벨+입력 필드 — 값이 있으면 흰 배경+초록 테두리, 비어있으면 크림 배경+placeholder 스타일.
/// 회원가입([features/onboarding/signup_screen.dart])·내 정보 수정 화면에서 공통으로 쓰인다.
class AppFormField extends StatelessWidget {
  const AppFormField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final hasValue = controller.text.trim().isNotEmpty;
    final borderColor = !enabled
        ? AppColors.formFieldBorder
        : (hasValue ? AppColors.primaryDark : AppColors.formFieldBorder);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.formLabel, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: label,
          textField: true,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            enabled: enabled,
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            style: TextStyle(
              fontSize: 15,
              color: enabled
                  ? const Color(0xFF222222)
                  : AppColors.formPlaceholder,
            ),
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: suffixIcon,
              hintStyle: TextStyle(
                color: enabled
                    ? AppColors.formPlaceholder
                    : AppColors.timelineDotGrey,
              ),
              filled: true,
              fillColor: (enabled && hasValue)
                  ? Colors.white
                  : AppColors.formFieldBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.primaryDark,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
