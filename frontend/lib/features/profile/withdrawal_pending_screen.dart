import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../state/auth_controller.dart';

class WithdrawalPendingScreen extends ConsumerWidget {
  const WithdrawalPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sync_problem,
                  size: 56,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 16),
                const Text(
                  '회원 탈퇴를 마무리해주세요',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  '카카오 연결은 해제됐지만 ColorTrip 계정 삭제 요청이 완료되지 않았습니다. '
                  '보안을 위해 로그인 상태를 유지한 채 다시 시도합니다.',
                  textAlign: TextAlign.center,
                ),
                if (auth.errorMessage case final error?) ...[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: auth.isBusy
                      ? null
                      : () => ref
                            .read(authControllerProvider.notifier)
                            .withdraw(),
                  child: auth.isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('탈퇴 다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
