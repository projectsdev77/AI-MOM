import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/config_error_app.dart';
import 'core/config/env.dart';
import 'core/providers/account_reset.dart';
import 'core/providers/currency_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/routing/password_recovery_flag.dart';
import 'core/services/notification_service.dart';
import 'core/services/purchases_service.dart';
import 'core/services/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isSupabaseConfigured) {
    runApp(const ConfigErrorApp());
    return;
  }

  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
  await PurchasesService.init();
  await NotificationService.init();
  await PushService.init();
  listenForPasswordRecovery();
  // Catches the app's custom URL scheme (see deep_links.dart) when a
  // password-reset email's link is tapped, exchanging its token for a
  // session — this is what actually completes the reset flow, since
  // there's nowhere else for that link to hand control back to the app.
  AppLinks().uriLinkStream.listen((uri) async {
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } catch (_) {
      // An unrelated or already-used/expired link — nothing to recover
      // from here; the reset-password screen surfaces a clear error if
      // the user does end up there without a valid recovery session.
    }
  });
  final savedCurrency = await loadSavedCurrency();
  final savedThemeMode = await loadSavedThemeMode();

  final container = ProviderContainer(
    overrides: [
      currencyProvider.overrideWith((ref) => savedCurrency),
      themeModeProvider.overrideWith((ref) => savedThemeMode),
    ],
  );
  listenForAccountChanges(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AiMomApp(),
    ),
  );
}
