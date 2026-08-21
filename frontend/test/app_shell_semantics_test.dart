/// 하단 탭(docs/specs/100-bottom-nav-redesign) — 실제 AppShell을 띄워 4탭 구성과
/// 미선택 탭의 스크린 리더 시맨틱(라벨·선택 상태)을 검증한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:colortrip/app/app_shell.dart';
import 'package:colortrip/data/repositories/domain_repository.dart';
import 'package:colortrip/state/repository_providers.dart';

/// 도메인 로딩은 이 테스트의 관심사가 아니다 — 어떤 호출도 실패시켜
/// 게이트를 에러 상태로 두고(하단 바는 게이트 밖이라 항상 그려진다) 바만 본다.
class _ThrowingDomainRepository implements DomainRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Widget _app() {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          for (final path in ['/home', '/travel', '/timeline', '/my'])
            StatefulShellBranch(
              routes: [
                GoRoute(path: path, builder: (_, _) => Text('화면 $path')),
              ],
            ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      domainRepositoryProvider.overrideWith(
        (ref) => _ThrowingDomainRepository(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('4탭이 그려지고 미선택 탭도 라벨·선택 상태 시맨틱을 노출한다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // 선택 탭(홈)은 라벨 텍스트가 보이고, 미선택 탭은 아이콘만 보인다.
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('타임라인'), findsNothing);

    // 미선택 탭도 시맨틱 라벨·선택 상태를 노출한다(스크린 리더 접근성).
    expect(
      tester.getSemantics(find.bySemanticsLabel('타임라인')),
      matchesSemantics(
        label: '타임라인',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('타임라인 탭을 누르면 타임라인 브랜치로 전환된다', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.timeline_rounded));
    await tester.pumpAndSettle();

    // 게이트(도메인 에러 상태)가 본문을 가리므로 pill 라벨 전환으로 확인한다.
    expect(find.text('타임라인'), findsOneWidget); // 선택 pill에 라벨 표시
    expect(find.text('홈'), findsNothing); // 이전 선택 pill 라벨은 접힘
  });
}
