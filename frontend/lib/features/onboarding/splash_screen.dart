import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../state/repository_providers.dart';

/// 스플래시 — Figma 스펙(2026-07-06 공유) 반영: 민트 카드 히어로 + 카카오 브랜드 버튼.
/// 카드 상단 일러스트는 에셋 미확보 상태라 아이콘 placeholder로 대체([implementation.md] 참고).
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.splashCardBackground,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Text('🗺️', style: TextStyle(fontSize: 96)),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 28,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '📍 여행 퀘스트',
                              style: TextStyle(
                                color: AppColors.splashAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '여행은 퀘스트,\n기록은 지도 위에.',
                              style: TextStyle(
                                color: AppColors.splashHeading,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '충청북도 곳곳을 탐험하고\n나만의 지도를 완성해보세요!',
                              style: TextStyle(
                                color: AppColors.splashAccent,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kakaoYellow,
                    foregroundColor: AppColors.kakaoLabel,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).loginWithKakao();
                    if (context.mounted) context.go('/signup');
                  },
                  child: const Text(
                    '카카오로 시작하기',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
