import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'state/home_tutorial_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final tutorialDismissed = await loadHomeTutorialDismissed();
  runApp(
    ProviderScope(
      overrides: [
        homeTutorialDismissedProvider.overrideWith(
          () => HomeTutorialNotifier(tutorialDismissed),
        ),
      ],
      child: const ColorTripApp(),
    ),
  );
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
      routerConfig: router,
    );
  }
}
