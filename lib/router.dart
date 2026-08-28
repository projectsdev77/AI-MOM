import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/preview_mode.dart';
import 'core/routing/go_router_refresh_stream.dart';
import 'features/chat/chat_history_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/tasks/tasks_screen.dart';
import 'features/track/finance_detail_screen.dart';
import 'features/track/health_detail_screen.dart';
import 'features/track/track_screen.dart';
import 'features/upgrade/upgrade_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/onboarding',
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  redirect: (context, state) {
    final loggedIn = Supabase.instance.client.auth.currentSession != null || previewModeEnabled;
    final onOnboarding = state.matchedLocation == '/onboarding';
    if (!loggedIn && !onOnboarding) return '/onboarding';
    if (loggedIn && onOnboarding) return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingFlow(),
    ),
    GoRoute(
      path: '/upgrade',
      builder: (context, state) => const UpgradeScreen(),
    ),
    GoRoute(
      path: '/track/finance',
      builder: (context, state) => const FinanceDetailScreen(),
    ),
    GoRoute(
      path: '/track/health',
      builder: (context, state) => const HealthDetailScreen(),
    ),
    GoRoute(
      path: '/chat/history',
      builder: (context, state) => const ChatHistoryScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/tasks', builder: (context, state) => const TasksScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/track', builder: (context, state) => const TrackScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        ]),
      ],
    ),
  ],
);
