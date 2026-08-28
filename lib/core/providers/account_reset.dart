import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state_provider.dart';
import 'service_providers.dart';
import 'track_providers.dart';

/// tasksProvider and profileProvider are plain (non-autoDispose)
/// providers, so their fetched state persists for the app's whole
/// lifetime once read — including across a sign-out or an account
/// deletion. Without this, signing into a different account (e.g.
/// deleting one and immediately creating a new one with the same
/// email, in the same app session) would keep showing the previous
/// account's tasks/profile until something happened to coincidentally
/// re-trigger a fetch. Listens for the signed-in user id actually
/// changing and invalidates every provider that caches per-account
/// data, so each refetches fresh for whoever is signed in now.
void listenForAccountChanges(ProviderContainer container) {
  String? lastUserId = Supabase.instance.client.auth.currentUser?.id;
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final newUserId = data.session?.user.id;
    if (newUserId == lastUserId) return;
    lastUserId = newUserId;

    container.invalidate(tasksProvider);
    container.invalidate(profileProvider);
    container.invalidate(expensesThisMonthProvider);
    container.invalidate(overallBudgetCentsProvider);
    container.invalidate(categoryBudgetsProvider);
    container.invalidate(healthActivitiesProvider);
    container.invalidate(healthGoalsProvider);
    container.invalidate(healthTodayProvider);
    container.invalidate(chatSessionsProvider);
  });
}
