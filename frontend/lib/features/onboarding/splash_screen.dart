import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../state/auth_controller.dart';

/// 스플래시 — Figma 스펙(2026-07-06 공유) 반영: 전체 화면 사진 배경 + 카카오 브랜드 버튼.
/// main_background_image 에셋(충북 산·호수 전경)을 화면 전체에 깔고, 텍스트·버튼은
/// 그 위에 어두운 그라데이션 스크림을 통해 가독성을 확보한 채 하단에 띄운다.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/main_background_image.png',
            fit: BoxFit.cover,
          ),
          // 하단 텍스트·버튼 가독성을 위한 스크림 — 사진 배경 위라 밝은 배경을 가정한
          // splashAccent/splashHeading 텍스트색 대신 흰 글씨로 바꿨다.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
                stops: [0.45, 1.0],
              ),
            ),
          ),
          // 화면 상단 10% 지점에 아이콘 + 제목 배치.
          Positioned(
            top: screenHeight * 0.13,
            left: 60,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/gps_mountain_icon.png',
                  width: 80,
                  height: 80,
                ),
                const Text(
                  '여행은 퀘스트,\n기록은 지도 위에.',
                  style: TextStyle(
                    color: AppColors.splashHeading,
                    fontSize: 45,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '충청북도 곳곳을 탐험하고\n나만의 지도를 완성해보세요!',
                  style: TextStyle(
                    color: AppColors.textStrong,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 72),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: screenSize.width * 0.85,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kakaoYellow,
                        foregroundColor: AppColors.kakaoLabel,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: auth.isBusy
                          ? null
                          : () => ref
                                .read(authControllerProvider.notifier)
                                .login(),
                      child: auth.isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              '카카오로 시작하기',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
