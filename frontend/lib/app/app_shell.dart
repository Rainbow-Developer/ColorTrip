import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../state/domain_state_gate.dart';

/// 홈/여행/타임라인/마이 하단 탭바 — 화면 위에 떠 있는 라운드 바로, 선택된 탭은
/// 아이콘+라벨 pill 캡슐로 확장된다(docs/specs/100-bottom-nav-redesign).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    (icon: Icons.home_rounded, label: '홈'),
    (icon: Icons.card_travel_rounded, label: '여행'),
    (icon: Icons.timeline_rounded, label: '타임라인'),
    (icon: Icons.person_rounded, label: '마이'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // 바가 떠 있으므로 body가 바 뒤까지 깔린다 — 각 탭 화면의 하단 패딩은
      // SafeArea·스크롤 패딩이 처리한다.
      extendBody: true,
      body: DomainStateGate(child: navigationShell),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          // 4탭이 균등 폭 슬롯을 갖는다 — 어느 탭을 선택해도 아이콘 위치가
          // 흔들리지 않는다. pill 라벨이 슬롯보다 길면 FittedBox로 살짝 줄인다.
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Center(
                    child: _NavItem(
                      icon: _items[i].icon,
                      label: _items[i].label,
                      selected: i == navigationShell.currentIndex,
                      onTap: () => navigationShell.goBranch(
                        i,
                        initialLocation: i == navigationShell.currentIndex,
                      ),
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

/// 탭 1개 — 선택되면 라벨이 펼쳐지는 pill로 확장된다. 균등 슬롯 안에서 그리며,
/// pill이 슬롯보다 길면 FittedBox가 축소해 잘리지 않는다.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    // 미선택 탭은 아이콘만 보이므로 스크린 리더용 라벨을 명시한다.
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedContainer(
              duration: _duration,
              curve: Curves.easeOut,
              height: 44,
              padding: EdgeInsets.symmetric(horizontal: selected ? 12 : 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryDark : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: selected ? Colors.white : AppColors.textMuted,
                  ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
