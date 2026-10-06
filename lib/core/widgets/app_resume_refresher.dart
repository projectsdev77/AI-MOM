import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state_provider.dart';
import '../providers/service_providers.dart';
import '../services/purchases_service.dart';

/// Brings the app up to date when it comes back to the foreground.
///
/// Without this, a plan change made outside the app (a purchase finished in
/// the store, a cancel or refund, the server flipping `profiles.plan`) only
/// showed up after the app was fully restarted. On every return to the
/// foreground, while signed in, it re-reads the profile (which holds the
/// server's plan), asks RevenueCat for fresh purchase state, reloads tasks,
/// and re-saves the device timezone.
///
/// Returning from the store's purchase or manage page counts as a resume too,
/// which is exactly when this is needed. Resumes closer together than
/// [minGap] are ignored so quick app switches don't hammer the server.
class AppResumeRefresher extends ConsumerStatefulWidget {
  const AppResumeRefresher({super.key, required this.child, this.minGap = const Duration(seconds: 5)});

  final Widget child;
  final Duration minGap;

  @override
  ConsumerState<AppResumeRefresher> createState() => _AppResumeRefresherState();
}

class _AppResumeRefresherState extends ConsumerState<AppResumeRefresher> with WidgetsBindingObserver {
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final auth = ref.read(authServiceProvider);
    if (auth.currentUser == null) return;

    final now = DateTime.now();
    final last = _lastRefresh;
    if (last != null && now.difference(last) < widget.minGap) return;
    _lastRefresh = now;

    ref.invalidate(profileProvider);
    // Each step on its own: one failing (offline, no store on this device)
    // must not stop the others.
    await Future.wait([
      _guard('purchases', PurchasesService.refreshCustomerInfo),
      _guard('tasks', ref.read(tasksProvider.notifier).refresh),
      _guard('timezone', auth.refreshTimezone),
    ]);
  }

  Future<void> _guard(String what, Future<void> Function() step) async {
    try {
      await step();
    } catch (e) {
      debugPrint('AppResumeRefresher: $what refresh failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
