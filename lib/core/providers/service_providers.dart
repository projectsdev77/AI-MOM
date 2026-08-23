import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../models/plan.dart';
import '../repositories/chat_repository.dart';
import '../repositories/finance_repository.dart';
import '../repositories/health_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/tasks_repository.dart';
import '../services/auth_service.dart';
import '../services/purchases_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(supabaseClientProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);

final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => TasksRepository(ref.watch(supabaseClientProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(supabaseClientProvider)),
);

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(ref.watch(supabaseClientProvider)),
);

final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => HealthRepository(ref.watch(supabaseClientProvider)),
);

/// Emits whenever Supabase's auth state changes (sign in/out/token
/// refresh) — screens watch this instead of polling `currentUser`.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange,
);

/// The signed-in user's profile row — name, Mom avatar, plan cache,
/// onboarding answers. Null while signed out.
final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(authStateProvider); // refetch on sign-in/out
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetch(userId);
});

// dart:io's Platform.isIOS/isAndroid throw on web instead of returning
// false, so kIsWeb has to be checked first — RevenueCat doesn't apply
// to a web build anyway (no App Store/Play Store to buy through there).
bool get _revenueCatConfiguredForPlatform {
  if (kIsWeb) return false;
  return Platform.isIOS ? Env.revenueCatIosKey.isNotEmpty : Env.revenueCatAndroidKey.isNotEmpty;
}

/// RevenueCat's live entitlement stream — empty (never emits) until a
/// real RevenueCat project is configured, so local dev without keys
/// falls through to [debugPlanOverrideProvider] below instead of hanging.
/// purchases_flutter exposes updates via a listener callback rather than
/// a Stream, so this adapts it to one.
final customerInfoProvider = StreamProvider<CustomerInfo?>((ref) {
  if (!_revenueCatConfiguredForPlatform) return const Stream.empty();

  final controller = StreamController<CustomerInfo>();
  void listener(CustomerInfo info) => controller.add(info);

  Purchases.addCustomerInfoUpdateListener(listener);
  Purchases.getCustomerInfo().then(controller.add).catchError((_) {});

  ref.onDispose(() {
    Purchases.removeCustomerInfoUpdateListener(listener);
    controller.close();
  });

  return controller.stream;
});

final entitlementPlanProvider = Provider<AppPlan?>((ref) {
  final info = ref.watch(customerInfoProvider).valueOrNull;
  if (info == null) return null;
  return PurchasesService.hasFullEntitlement(info) ? AppPlan.full : AppPlan.basic;
});

/// The `profiles.plan` cache, kept current by the RevenueCat webhook —
/// this is also what the mom-chat edge function checks server-side, so
/// it's the second-best source of truth after a live entitlement.
final cachedPlanProvider = Provider<AppPlan?>((ref) {
  final planName = ref.watch(profileProvider).valueOrNull?['plan'] as String?;
  if (planName == null) return null;
  return AppPlan.values.byName(planName);
});

/// Manual plan override for local development/demoing without a
/// RevenueCat project configured — see the Settings screen's debug
/// toggle. Ignored the moment a real entitlement or cached plan is
/// available.
final debugPlanOverrideProvider = StateProvider<AppPlan>((ref) => AppPlan.basic);

final planProvider = Provider<AppPlan>((ref) {
  return ref.watch(entitlementPlanProvider) ??
      ref.watch(cachedPlanProvider) ??
      ref.watch(debugPlanOverrideProvider);
});
