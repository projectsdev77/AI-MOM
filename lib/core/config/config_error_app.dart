import 'package:flutter/material.dart';

/// Shown instead of the real app when required --dart-define values are
/// missing, so a misconfigured run fails with a readable message rather
/// than a null Supabase client crash three screens in.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F1EC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Missing SUPABASE_URL / SUPABASE_ANON_KEY.\n\n'
              'Run with --dart-define-from-file=config/local.json '
              '(see README.md).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}
