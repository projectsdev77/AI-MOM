import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_spacing.dart';

/// Shared scaffold for the plain scrollable legal/help pages.
class _TextScreen extends StatelessWidget {
  const _TextScreen({required this.title, required this.sections});
  final String title;
  final List<(String heading, String body)> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          for (final (heading, body) in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(heading, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TextScreen(
      title: 'Terms of Service',
      sections: [
        (
          'What this is',
          "AI Mom is a personal productivity and wellness app: an AI \"Mom\" persona that checks in on your "
              'tasks, habits, spending, and health. It is not a medical, financial, or mental health service, '
              "and Mom's replies are AI-generated — treat them as encouragement and reminders, not professional advice.",
        ),
        (
          'Your account',
          'You need an account to use AI Mom. You are responsible for keeping your login details private and '
              'for what happens under your account. You must be old enough to legally agree to these terms in '
              'your country to sign up.',
        ),
        (
          'Subscriptions',
          'Basic is free. Full Mom Experience is a paid subscription billed through the Apple App Store or '
              'Google Play, on their standard terms — we never see or store your card details. You can cancel '
              'anytime through your Apple ID or Google Play account settings; access continues until the end of '
              'the paid period.',
        ),
        (
          'Acceptable use',
          "Don't use AI Mom to do anything illegal, to abuse or overload the service, or to try to extract, "
              'scrape, or resell the data of other users. Chat with Mom in good faith — attempts to misuse the '
              'chat feature (e.g. to generate harmful content) may get your access suspended.',
        ),
        (
          'If you\'re in crisis',
          'Mom is not a crisis service. If you or someone else is in immediate danger, please contact local '
              'emergency services or a crisis line (in the US: 988 Suicide & Crisis Lifeline) directly.',
        ),
        (
          'Changes and termination',
          'We may update these terms or the app itself over time, and may suspend or close accounts that '
              'violate them. You can delete your account and all its data at any time from Settings.',
        ),
        (
          'Contact',
          'Questions about these terms? Reach us from the Help & contact support screen.',
        ),
      ],
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TextScreen(
      title: 'Privacy Policy',
      sections: [
        (
          'What we collect',
          'Your account email and name; your onboarding answers (goals, habits you procrastinate on, daily '
              "routine, living situation, motivation style, and anything you write about what's stressing you "
              'out); the tasks, habits, and streaks you create; your chat messages with Mom; expenses and '
              'budgets you log; and health data you log (water, sleep, movement, and any custom activities). '
              'All of it is entered by you — AI Mom does not read your contacts, photos, or other apps.',
        ),
        (
          'Why we collect it',
          "To make the app work: showing your tasks back to you, calculating streaks, giving Mom the context "
              "she needs to reply about your real situation, and tracking your spending and health against the "
              "goals you set. We don't use your data for advertising, and we don't sell it to anyone.",
        ),
        (
          'Who else sees it',
          'Three outside services process data on our behalf, only as needed to run the app: Supabase hosts '
              'the database and handles login; Google (Gemini API) receives your chat messages and the app '
              'context needed to generate Mom\'s replies; RevenueCat handles subscription billing through '
              "Apple/Google and only sees what's needed for that (not your chats, tasks, or health data). None "
              'of them are permitted to use your data for their own purposes.',
        ),
        (
          'How long we keep it',
          "Your data stays until you delete your account, at which point everything — tasks, chats, financial "
              "and health logs, onboarding answers — is permanently deleted, not just hidden. There's no "
              'recovery period after that, so account deletion is final.',
        ),
        (
          'Your choices',
          "You can edit or delete individual tasks, expenses, health logs, and chat conversations at any time. "
              'You can delete your entire account and all associated data from Settings → Delete account.',
        ),
        (
          'Contact',
          'Questions about your data? Reach us from the Help & contact support screen.',
        ),
      ],
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _supportEmail = 'support@example.com';

  Future<void> _emailSupport(BuildContext context) async {
    final uri = Uri(scheme: 'mailto', path: _supportEmail, query: 'subject=AI Mom support');
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email us at $_supportEmail')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help & contact support')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          for (final (q, a) in const [
            ('Mom isn\'t replying, or says "not answering right now"', 'Check your internet connection and try again in a moment — this usually means a temporary hiccup reaching Mom\'s AI, not something wrong with your account.'),
            ('I hit my weekly chat limit', 'Basic Mom includes 15 messages a week with Mom; it resets on a rolling 7-day basis. Full Mom Experience removes the limit.'),
            ('I want to change my email or password', 'Settings → Account → Change email / Change password.'),
            ('I want to delete my account', 'Settings → Account → Delete account. This is permanent and removes everything immediately.'),
            ('A subscription charge looks wrong', 'Subscriptions are billed and managed entirely by Apple or Google — check Settings → Manage subscription, or your App Store/Play Store account directly.'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(a, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () => _emailSupport(context),
            child: const Text('Email support'),
          ),
        ],
      ),
    );
  }
}
