import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() {
  runApp(const ProviderScope(child: ColorTripApp()));
}

class ColorTripApp extends ConsumerWidget {
  const ColorTripApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '다채로울지도',
      debugShowCheckedModeBanner: false,
      theme: ColorTripTheme.light(),
      // 날짜 피커 등 Material 위젯 한국어화(여행 기간 입력에 사용).
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    );
  }
}
