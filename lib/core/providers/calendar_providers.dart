import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'service_providers.dart';

/// Which dates in a given month have completed tasks, for the dashboard
/// calendar's day dots and per-day summary. Keyed by the month's first
/// day (year/month only — day/time are ignored by the caller) so the
/// same month reuses one cached fetch.
final monthCompletionsProvider = FutureProvider.autoDispose.family<Map<String, List<String>>, DateTime>(
  (ref, month) async {
    final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return const {};
    return ref.watch(tasksRepositoryProvider).fetchCompletionsForMonth(userId, month);
  },
);
