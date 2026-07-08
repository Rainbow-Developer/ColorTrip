import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';

/// 여행/홈/마이 탭바 — 선택된 탭 아이콘에 원형 배지를 얹는 스타일([Figma] 여행 목록 화면 하단 nav).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    (icon: Icons.card_travel_rounded, label: '여행'),
    (icon: Icons.home_rounded, label: '홈'),
    (icon: Icons.person_rounded, label: '마이'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < _items.length; i++)
                  _NavItem(
                    icon: _items[i].icon,
                    label: _items[i].label,
                    selected: i == navigationShell.currentIndex,
                    onTap: () => navigationShell.goBranch(
                      i,
                      initialLocation: i == navigationShell.currentIndex,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryDark : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: selected ? Colors.white : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primaryDark : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
