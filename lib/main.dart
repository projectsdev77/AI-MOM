import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/config_error_app.dart';
import 'core/config/env.dart';
import 'core/providers/currency_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/purchases_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isSupabaseConfigured) {
    runApp(const ConfigErrorApp());
    return;
  }

  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
  await PurchasesService.init();
  final savedCurrency = await loadSavedCurrency();
  final savedThemeMode = await loadSavedThemeMode();

  runApp(
    ProviderScope(
      overrides: [
        currencyProvider.overrideWith((ref) => savedCurrency),
        themeModeProvider.overrideWith((ref) => savedThemeMode),
      ],
      child: const AiMomApp(),
    ),
  );
}
