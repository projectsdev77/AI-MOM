import 'dart:async';

import 'package:flutter/foundation.dart';

/// Turns a Stream (here, Supabase's auth state change stream) into a
/// [Listenable] GoRouter can use as `refreshListenable`, so a sign-in or
/// sign-out re-evaluates the router's redirect logic immediately.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
