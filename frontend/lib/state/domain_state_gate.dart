import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'domain_controller.dart';

class DomainStateGate extends ConsumerWidget {
  const DomainStateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(domainControllerProvider)
        .when(
          data: (_) => child,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '여행 정보를 불러오지 못했어요',
                    style: TextStyle(
                      color: AppColors.textStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '네트워크를 확인한 뒤 다시 시도해주세요.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(domainControllerProvider),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
        );
  }
}
