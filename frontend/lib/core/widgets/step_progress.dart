import 'package:flutter/material.dart';

import '../constants.dart';

/// 단계 진행 막대(총 N칸 중 앞에서부터 [currentStep]칸 채움).
///
/// 회원가입에서 2/3 고정으로 쓰이다가(단계 정의가 없어 의미가 없었다) 여행 DNA 설문으로
/// 옮겼다(KAN-75) — 문항 수만큼 칸을 만들어 "4문항 중 지금 몇 번째"를 보여준다.
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.totalSteps,
    required this.currentStep,
  });

  /// 전체 칸 수(1 이상).
  final int totalSteps;

  /// 채울 칸 수(0 ~ [totalSteps]). 범위를 벗어나면 잘라서 그린다.
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final filled = currentStep.clamp(0, totalSteps);
    return Semantics(
      label: '진행 단계 $totalSteps 중 $filled',
      child: Row(
        children: [
          for (var i = 0; i < totalSteps; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 4),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < filled
                        ? AppColors.primaryDark
                        : const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
