import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 화면 하단에 잠깐 떴다 사라지는 토스트 — 프로토타입의 `.toast` 스타일을 옮김.
void showAppToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    // 셸 탭 화면이면 MediaQuery 하단 패딩에 떠 있는 하단탭 높이가 들어 있고,
    // 그 외 화면이면 시스템 내비게이션 바 인셋만 들어 있다 — 어느 쪽이든
    // 가려지지 않게 그만큼 띄운다.
    builder: (context) => Positioned(
      left: 0,
      right: 0,
      bottom: math.max(96.0, 40 + MediaQuery.paddingOf(context).bottom),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xF0163319),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 1900), entry.remove);
}
