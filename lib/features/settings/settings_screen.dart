import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/check_in_frequency.dart';
import '../../core/models/plan.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/providers/currency_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/purchases_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/utils/password.dart';
import '../../core/widgets/mom_avatar.dart';
import '../../core/widgets/section_header.dart';
import 'legal_screens.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmAndRun({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel, style: const TextStyle(color: AppColors.moodDisappointed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  Future<void> _pickCheckInFrequency(BuildContext context, WidgetRef ref, String current) async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Check-in frequency'),
        children: [
          for (final option in checkInFrequencyOptions)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, option),
              child: Row(
                children: [
                  Icon(
                    option == current ? LucideIcons.circleCheck : LucideIcons.circle,
                    size: 18,
                    color: option == current ? AppColors.accent : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(option),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    try {
      await ref.read(profileRepositoryProvider).updateCheckInFrequency(userId: userId, frequency: selected);
      ref.invalidate(profileProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  Future<void> _pickCurrency(BuildContext context, WidgetRef ref, String current) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Currency'),
        children: [
          for (final code in currencySymbols.keys)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, code),
              child: Row(
                children: [
                  Icon(
                    code == current ? LucideIcons.circleCheck : LucideIcons.circle,
                    size: 18,
                    color: code == current ? AppColors.accent : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('$code (${currencySymbols[code]})'),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    ref.read(currencyProvider.notifier).state = selected;
    await saveCurrency(selected);
  }

  Future<void> _pickAppearance(BuildContext context, WidgetRef ref, ThemeMode current) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Appearance'),
        children: [
          for (final mode in ThemeMode.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, mode),
              child: Row(
                children: [
                  Icon(
                    mode == current ? LucideIcons.circleCheck : LucideIcons.circle,
                    size: 18,
                    color: mode == current ? AppColors.accent : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(themeModeLabel(mode)),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    ref.read(themeModeProvider.notifier).state = selected;
    await saveThemeMode(selected);
  }

  void _changeAvatar(BuildContext context, WidgetRef ref, MomAvatarStyle current) {
    showMomAvatarPicker(
      context,
      current: current,
      onSelected: (style) async {
        ref.read(momAvatarStyleProvider.notifier).state = style;
        final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
        if (userId == null) return;
        try {
          await ref.read(profileRepositoryProvider).updateMomAvatarStyle(userId: userId, style: style.name);
          ref.invalidate(profileProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
          }
        }
      },
    );
  }

  Future<void> _changeEmail(BuildContext context, WidgetRef ref, String currentEmail) async {
    final controller = TextEditingController(text: currentEmail);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change email'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'New email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final email = controller.text.trim();
              if (!email.contains('@')) return;
              try {
                await ref.read(authServiceProvider).updateEmail(email);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Check $email to confirm the change.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change password'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'New password (min. 8 characters)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: isStrongPassword(controller.text)
                  ? () async {
                      try {
                        await ref.read(authServiceProvider).updatePassword(controller.text);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password updated.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                        }
                      }
                    }
                  : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _manageSubscription(BuildContext context) async {
    final url = kIsWeb
        ? null
        : (Platform.isIOS
            ? 'itms-apps://apps.apple.com/account/subscriptions'
            : 'https://play.google.com/store/account/subscriptions');
    if (url == null || !await launchUrl(Uri.parse(url))) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manage your subscription from your App Store or Play Store account.')),
        );
      }
    }
  }

  Future<void> _openNotificationSettings(BuildContext context) async {
    if (kIsWeb || !(await openAppSettings())) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Open your phone's Settings app to manage AI Mom's notifications.")),
        );
      }
    }
  }

  Future<void> _setPushNudgesEnabled(BuildContext context, WidgetRef ref, bool enabled) async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    try {
      await ref.read(profileRepositoryProvider).updatePushNudgesEnabled(userId: userId, enabled: enabled);
      ref.invalidate(profileProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final authService = ref.read(authServiceProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final checkInFrequency = (profile?['check_in_frequency'] as String?) ?? checkInFrequencyOptions.first;
    final currency = ref.watch(currencyProvider);
    final themeMode = ref.watch(themeModeProvider);
    final avatarStyle = ref.watch(effectiveMomAvatarProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _Group(title: 'Account', rows: [
            _Row(icon: LucideIcons.user, label: 'Profile', value: user?.userMetadata?['name'] as String? ?? ''),
            _Row(
              icon: LucideIcons.mail,
              label: 'Change email',
              value: user?.email ?? '',
              onTap: () => _changeEmail(context, ref, user?.email ?? ''),
            ),
            _Row(
              icon: LucideIcons.lock,
              label: 'Change password',
              onTap: () => _changePassword(context, ref),
            ),
            _Row(
              icon: LucideIcons.userX,
              label: 'Delete account',
              destructive: true,
              onTap: () => _confirmAndRun(
                context: context,
                title: 'Delete your account?',
                message: 'This permanently deletes your tasks, chat history, spending, and health data. This cannot be undone.',
                confirmLabel: 'Delete',
                action: authService.deleteAccount,
              ),
            ),
          ]),
          _Group(title: 'Subscription', rows: [
            _Row(icon: LucideIcons.crown, label: 'Current plan', value: plan.displayName),
            _Row(
              icon: LucideIcons.refreshCw,
              label: 'Restore purchases',
              onTap: PurchasesService.restorePurchases,
            ),
            _Row(
              icon: LucideIcons.externalLink,
              label: 'Manage subscription',
              onTap: () => _manageSubscription(context),
            ),
          ]),
          _Group(title: 'Mom', rows: [
            _Row(
              icon: LucideIcons.smile,
              label: "Change Mom's avatar",
              onTap: () => _changeAvatar(context, ref, avatarStyle),
            ),
            _Row(
              icon: LucideIcons.bellRing,
              label: 'Check-in frequency',
              value: checkInFrequency,
              onTap: () => _pickCheckInFrequency(context, ref, checkInFrequency),
            ),
          ]),
          _Group(title: 'Notifications', rows: [
            _Row(
              icon: LucideIcons.bell,
              label: 'System notification settings',
              onTap: () => _openNotificationSettings(context),
            ),
          ]),
          _SwitchGroup(
            title: 'Mom checking in',
            icon: LucideIcons.messageCircleHeart,
            label: "Nudge me about today's list",
            value: (profile?['push_nudges_enabled'] as bool?) ?? true,
            onChanged: (enabled) => _setPushNudgesEnabled(context, ref, enabled),
          ),
          _Group(title: 'Preferences', rows: [
            _Row(
              icon: LucideIcons.badgeDollarSign,
              label: 'Currency',
              value: currency,
              onTap: () => _pickCurrency(context, ref, currency),
            ),
            _Row(
              icon: LucideIcons.moonStar,
              label: 'Appearance',
              value: themeModeLabel(themeMode),
              onTap: () => _pickAppearance(context, ref, themeMode),
            ),
          ]),
          _Group(title: 'Support & legal', rows: [
            _Row(
              icon: LucideIcons.circleHelp,
              label: 'Help & contact support',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
            ),
            _Row(
              icon: LucideIcons.fileText,
              label: 'Terms of Service',
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsOfServiceScreen())),
            ),
            _Row(
              icon: LucideIcons.shieldCheck,
              label: 'Privacy Policy',
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
            ),
            _Row(
              icon: LucideIcons.scrollText,
              label: 'Open-source licenses',
              onTap: () => showLicensePage(context: context, applicationName: 'AI Mom'),
            ),
          ]),
          _Group(title: 'Session', rows: [
            _Row(
              icon: LucideIcons.logOut,
              label: 'Log out',
              onTap: () => _confirmAndRun(
                context: context,
                title: 'Log out?',
                message: "You'll need to sign back in to see your tasks and chats.",
                confirmLabel: 'Log out',
                action: authService.signOut,
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          const _DebugPlanToggle(),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});
  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i != rows.length - 1)
                    Divider(height: 1, color: theme.dividerTheme.color),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchGroup extends StatelessWidget {
  const _SwitchGroup({
    required this.title,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.onSurface),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
                  Switch(value: value, onChanged: onChanged),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.value, this.destructive = false, this.onTap});
  final IconData icon;
  final String label;
  final String? value;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? AppColors.moodDisappointed : theme.colorScheme.onSurface;
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: theme.textTheme.bodyLarge?.copyWith(color: color))),
            if (value != null && value!.isNotEmpty)
              Text(value!, style: theme.textTheme.bodySmall),
            const SizedBox(width: AppSpacing.xs),
            Icon(LucideIcons.chevronRight, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }
}

/// Dev-only control to preview Basic vs Full gating — not a shipped
/// feature, remove once RevenueCat entitlements drive [planProvider].
class _DebugPlanToggle extends ConsumerWidget {
  const _DebugPlanToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
        border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Debug: preview plan', style: theme.textTheme.bodySmall),
          ),
          Switch(
            value: plan.isFull,
            activeThumbColor: AppColors.accent,
            onChanged: (v) => ref.read(debugPlanOverrideProvider.notifier).state =
                v ? AppPlan.full : AppPlan.basic,
          ),
        ],
      ),
    );
  }
}
