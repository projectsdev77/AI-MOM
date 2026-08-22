import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/plan.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/purchases_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/section_header.dart';

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
    if (confirmed == true) await action();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final authService = ref.read(authServiceProvider);

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
            _Row(icon: LucideIcons.mail, label: 'Change email', value: user?.email ?? ''),
            const _Row(icon: LucideIcons.lock, label: 'Change password'),
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
            const _Row(icon: LucideIcons.externalLink, label: 'Manage subscription'),
          ]),
          const _Group(title: 'Mom', rows: [
            _Row(icon: LucideIcons.smile, label: 'Change Mom\'s avatar'),
            _Row(icon: LucideIcons.bellRing, label: 'Check-in frequency', value: 'A few times a day'),
          ]),
          const _Group(title: 'Notifications', rows: [
            _Row(icon: LucideIcons.bell, label: 'System notification settings'),
          ]),
          const _Group(title: 'Preferences', rows: [
            _Row(icon: LucideIcons.badgeDollarSign, label: 'Currency', value: 'USD'),
            _Row(icon: LucideIcons.ruler, label: 'Units', value: 'Imperial'),
            _Row(icon: LucideIcons.moonStar, label: 'Appearance', value: 'System'),
          ]),
          const _Group(title: 'Support & legal', rows: [
            _Row(icon: LucideIcons.circleHelp, label: 'Help & contact support'),
            _Row(icon: LucideIcons.fileText, label: 'Terms of Service'),
            _Row(icon: LucideIcons.shieldCheck, label: 'Privacy Policy'),
            _Row(icon: LucideIcons.scrollText, label: 'Open-source licenses'),
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
