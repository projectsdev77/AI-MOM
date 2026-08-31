import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../config/env.dart';
import 'notification_service.dart';

/// Firebase Cloud Messaging: receives Mom's proactive nudges, sent by
/// the `send-nudges` edge function on a schedule (see that function's
/// header comment for the server side of this). Separate from
/// [NotificationService], which handles on-device task reminders that
/// don't need a network round trip at all.
class PushService {
  PushService._();

  static bool _ready = false;

  static FirebaseOptions get _options => FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseAppId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        projectId: Env.firebaseProjectId,
        authDomain: Env.firebaseAuthDomain.isNotEmpty ? Env.firebaseAuthDomain : null,
        storageBucket: Env.firebaseStorageBucket.isNotEmpty ? Env.firebaseStorageBucket : null,
      );

  /// No-op until a real Firebase project is configured (see README) —
  /// same "gracefully do nothing instead of crashing" pattern as
  /// [PurchasesService] before a RevenueCat project exists.
  static Future<void> init() async {
    if (!Env.isFirebaseConfigured) return;
    try {
      await Firebase.initializeApp(options: _options);
    } catch (_) {
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        NotificationService.showNow(
          title: notification.title ?? 'Mom',
          body: notification.body ?? '',
        );
      }
    });

    _ready = true;
  }

  /// Call once signed in — saves this device's token so the
  /// send-nudges function knows where to deliver Mom's nudges, and
  /// keeps it current if Firebase rotates the token later.
  ///
  /// A flaky Play Services install (out of date, missing, whatever) can
  /// make `getToken()` throw — this must never propagate, both because
  /// it's called unguarded at every app launch (main.dart) where an
  /// uncaught exception would stop the rest of startup from running,
  /// and because it's also called from interactive sign-in, where a
  /// throw here would otherwise surface as a false "sign-in failed" to
  /// someone whose account sign-in actually succeeded.
  static Future<void> registerToken(Future<void> Function(String token) onToken) async {
    if (!_ready || kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await onToken(token);
      FirebaseMessaging.instance.onTokenRefresh.listen(onToken);
    } catch (_) {
      // Push just won't work on this device until whatever's wrong
      // (usually stale Play Services) is fixed — not worth taking
      // anything else down over.
    }
  }
}
