import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/plan.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/section_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    final name = ref.watch(userNameProvider);

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
            _Row(icon: LucideIcons.user, label: 'Profile', value: name),
            const _Row(icon: LucideIcons.mail, label: 'Change email'),
            const _Row(icon: LucideIcons.lock, label: 'Change password'),
            const _Row(icon: LucideIcons.userX, label: 'Delete account', destructive: true),
          ]),
          _Group(title: 'Subscription', rows: [
            _Row(icon: LucideIcons.crown, label: 'Current plan', value: plan.displayName),
            const _Row(icon: LucideIcons.refreshCw, label: 'Restore purchases'),
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
          const _Group(title: 'Session', rows: [
            _Row(icon: LucideIcons.logOut, label: 'Log out', destructive: false),
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
  const _Row({required this.icon, required this.label, this.value, this.destructive = false});
  final IconData icon;
  final String label;
  final String? value;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? AppColors.moodDisappointed : theme.colorScheme.onSurface;
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: theme.textTheme.bodyLarge?.copyWith(color: color))),
            if (value != null)
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
            onChanged: (v) => ref.read(planProvider.notifier).state =
                v ? AppPlan.full : AppPlan.basic,
          ),
        ],
      ),
    );
  }
}
