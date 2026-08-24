import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/plan.dart';
import '../../core/providers/currency_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/track_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/locked_feature_overlay.dart';

/// A summary of both trackers — tap either card for the real, detailed
/// page (`/track/finance`, `/track/health`). Kept deliberately light:
/// this screen's job is "what's the state of things," not editing.
class TrackScreen extends ConsumerWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);

    Widget content = ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
      children: [
        _FinanceSummaryCard(onTap: () => context.push('/track/finance')),
        const SizedBox(height: AppSpacing.lg),
        _HealthSummaryCard(onTap: () => context.push('/track/health')),
      ],
    );

    if (!plan.isFull) {
      content = LockedFeatureOverlay(
        featureName: 'Financial & health tracking',
        onUpgradeTap: () => context.push('/upgrade'),
        child: content,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Track')),
      body: content,
    );
  }
}

class _FinanceSummaryCard extends ConsumerWidget {
  const _FinanceSummaryCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesThisMonthProvider);
    final budgetAsync = ref.watch(overallBudgetCentsProvider);

    final spentCents = expensesAsync.valueOrNull?.fold<int>(0, (sum, e) => sum + e.amountCents) ?? 0;
    final budgetCents = budgetAsync.valueOrNull;
    final ratio = budgetCents != null && budgetCents > 0 ? (spentCents / budgetCents).clamp(0.0, 1.0) : 0.0;
    final currency = ref.watch(currencyProvider);

    return _SummaryCard(
      onTap: onTap,
      icon: LucideIcons.wallet,
      tint: ChipTint.tan,
      title: 'Financial',
      value: budgetCents != null
          ? '${formatMoney(spentCents, currency)} of ${formatMoney(budgetCents, currency)} spent'
          : '${formatMoney(spentCents, currency)} spent so far',
      progress: budgetCents != null ? ratio : null,
    );
  }
}

class _HealthSummaryCard extends ConsumerWidget {
  const _HealthSummaryCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(healthGoalsProvider).valueOrNull;
    final today = ref.watch(healthTodayProvider).valueOrNull;

    final value = goals == null
        ? 'Set your goals to start tracking'
        : '${today?.waterCount ?? 0}/${goals.waterTarget} water · '
            '${today?.workoutMinutes ?? 0}/${goals.workoutTargetMinutes}m active';

    return _SummaryCard(
      onTap: onTap,
      icon: LucideIcons.heartPulse,
      tint: ChipTint.sage,
      title: 'Health',
      value: value,
      progress: null,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.onTap,
    required this.icon,
    required this.tint,
    required this.title,
    required this.value,
    required this.progress,
  });

  final VoidCallback onTap;
  final IconData icon;
  final ChipTint tint;
  final String title;
  final String value;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight),
        ),
        child: Row(
          children: [
            CategoryIconBadge(icon: icon, tint: tint, size: 44),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(value, style: theme.textTheme.bodySmall),
                  if (progress != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.chipPeach,
                        valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }
}
