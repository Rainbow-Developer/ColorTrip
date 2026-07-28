import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/verification.dart';
import '../features/home/home_screen.dart';
import '../features/home/share_card_screen.dart';
import '../features/onboarding/signup_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/withdrawal_pending_screen.dart';
import '../features/quests/photo_verify_result_screen.dart';
import '../features/quests/quest_detail_screen.dart';
import '../features/quests/quest_list_screen.dart';
import '../features/quests/quest_verify_screen.dart';
import '../features/quests/region_overview_screen.dart';
import '../features/quests/region_quest_select_screen.dart';
import '../features/trip_dna/dna_result_screen.dart';
import '../features/trip_dna/trip_dna_screen.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/travel/travel_list_screen.dart';
import '../state/auth_controller.dart';
import '../state/domain_state_gate.dart';
import 'app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.notify());
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/trip-dna',
        builder: (context, state) => const TripDnaScreen(),
      ),
      GoRoute(
        path: '/trip-dna/result',
        builder: (context, state) => const DnaResultScreen(),
      ),
      GoRoute(
        path: '/timeline',
        builder: (context, state) =>
            const DomainStateGate(child: TimelineScreen()),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/withdrawal-pending',
        builder: (context, state) => const WithdrawalPendingScreen(),
      ),
      GoRoute(
        path: '/region/:id',
        builder: (context, state) => DomainStateGate(
          child: RegionOverviewScreen(
            regionId: state.pathParameters['id']!,
            journeyId: state.uri.queryParameters['journeyId'],
          ),
        ),
        routes: [
          GoRoute(
            path: 'quests',
            builder: (context, state) => DomainStateGate(
              child: RegionQuestSelectScreen(
                regionId: state.pathParameters['id']!,
                journeyId: state.uri.queryParameters['journeyId'],
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/quest/:id',
        builder: (context, state) => DomainStateGate(
          child: QuestDetailScreen(questId: state.pathParameters['id']!),
        ),
        routes: [
          GoRoute(
            path: 'verify',
            builder: (context, state) => DomainStateGate(
              child: QuestVerifyScreen(
                questId: state.pathParameters['id']!,
                journeyId: state.uri.queryParameters['journeyId'],
              ),
            ),
            routes: [
              GoRoute(
                path: 'result',
                builder: (context, state) {
                  final extra = state.extra;
                  return DomainStateGate(
                    child: PhotoVerifyResultScreen(
                      questId: state.pathParameters['id']!,
                      verdict: extra is PhotoVerdict ? extra : null,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/quests',
        builder: (context, state) =>
            const DomainStateGate(child: QuestListScreen()),
      ),
      GoRoute(
        path: '/share',
        builder: (context, state) =>
            const DomainStateGate(child: ShareCardScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/travel',
                builder: (context, state) => const TravelListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

String? authRedirect(AuthState auth, String location) {
  final authenticatedOnlyExit =
      location == '/splash' ||
      location == '/signup' ||
      location == '/trip-dna' ||
      location == '/withdrawal-pending';
  return switch (auth.status) {
    AuthStatus.checking => location == '/splash' ? null : '/splash',
    AuthStatus.unauthenticated => location == '/splash' ? null : '/splash',
    AuthStatus.failure => location == '/splash' ? null : '/splash',
    AuthStatus.profileRequired => location == '/signup' ? null : '/signup',
    AuthStatus.tripDnaRequired => location == '/trip-dna' ? null : '/trip-dna',
    AuthStatus.authenticated => authenticatedOnlyExit ? '/home' : null,
    AuthStatus.withdrawalPending =>
      location == '/withdrawal-pending' ? null : '/withdrawal-pending',
  };
}
