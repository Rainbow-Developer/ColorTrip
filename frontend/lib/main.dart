import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/config/app_config.dart';
import 'core/network/dio_client.dart';
import 'features/onboarding/config_error_app.dart';
import 'state/auth_controller.dart';
import 'state/onboarding_tour_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  late final AppConfig config;
  try {
    config = AppConfig.fromBuildEnvironment();
  } on StateError catch (error) {
    runApp(ConfigErrorApp(message: error.message.toString()));
    return;
  }
  await KakaoSdk.init(nativeAppKey: config.kakaoNativeAppKey);
  final onboardingTour = await loadOnboardingTourState();
  late final ProviderContainer container;
  container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      sessionExpiredCallbackProvider.overrideWithValue(
        () => container.read(authControllerProvider.notifier).sessionExpired(),
      ),
      onboardingRequiredCallbackProvider.overrideWithValue(
        () => container
            .read(authControllerProvider.notifier)
            .refreshCurrentUser(),
      ),
      onboardingTourProvider.overrideWith(
        () => OnboardingTourNotifier(onboardingTour),
      ),
    ],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ColorTripApp(),
    ),
  );
  unawaited(container.read(authControllerProvider.notifier).bootstrap());
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