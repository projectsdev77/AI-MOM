import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'router.dart';

class AiMomApp extends StatelessWidget {
  const AiMomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AI Mom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
