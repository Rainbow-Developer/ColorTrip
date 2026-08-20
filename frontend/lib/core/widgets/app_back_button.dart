import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// AppBar `leading`용 뒤로가기 버튼 — 모든 화면에서 동일한 스타일로 통일한다.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallbackLocation});

  final String? fallbackLocation;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final canPop = navigator.canPop();
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
      onPressed: canPop
          ? navigator.maybePop
          : fallbackLocation == null
          ? null
          : () => context.go(fallbackLocation!),
    );
  }
}
