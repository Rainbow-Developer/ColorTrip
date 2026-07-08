import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/home/share_card_screen.dart';
import '../features/onboarding/signup_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/quests/photo_verify_result_screen.dart';
import '../features/quests/quest_detail_screen.dart';
import '../features/quests/quest_list_screen.dart';
import '../features/quests/quest_verify_screen.dart';
import '../features/quests/region_overview_screen.dart';
import '../features/quests/region_quest_select_screen.dart';
import '../features/survey/dna_result_screen.dart';
import '../features/survey/survey_screen.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/travel/travel_list_screen.dart';
import 'app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
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
        path: '/survey',
        builder: (context, state) => const SurveyScreen(),
      ),
      GoRoute(
        path: '/dna-result',
        builder: (context, state) => const DnaResultScreen(),
      ),
      GoRoute(
        path: '/timeline',
        builder: (context, state) => const TimelineScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/region/:id',
        builder: (context, state) =>
            RegionOverviewScreen(regionId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'quests',
            builder: (context, state) =>
                RegionQuestSelectScreen(regionId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/quest/:id',
        builder: (context, state) =>
            QuestDetailScreen(questId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'verify',
            builder: (context, state) =>
                QuestVerifyScreen(questId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'result',
                builder: (context, state) => PhotoVerifyResultScreen(
                  questId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/quests',
        builder: (context, state) => const QuestListScreen(),
      ),
      GoRoute(
        path: '/share',
        builder: (context, state) => const ShareCardScreen(),
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
});
