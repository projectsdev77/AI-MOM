import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/plan.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/track_providers.dart';
import '../../core/repositories/finance_repository.dart';
import '../../core/repositories/health_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/locked_feature_overlay.dart';
import '../../core/widgets/section_header.dart';
import 'finance_widgets.dart';
import 'health_widgets.dart';

class TrackScreen extends ConsumerWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    final theme = Theme.of(context);

    Widget financeCard = const _FinanceCard();
    Widget healthCard = const _HealthCard();
    if (!plan.isFull) {
      financeCard = LockedFeatureOverlay(featureName: 'Financial tracking', child: financeCard);
      healthCard = LockedFeatureOverlay(featureName: 'Health tracking', child: healthCard);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Track')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          if (!plan.isFull)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                'Financial and health tracking are part of Full Mom Experience.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SectionHeader(title: 'Spending'),
          const SizedBox(height: AppSpacing.sm),
          financeCard,
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Health'),
          const SizedBox(height: AppSpacing.sm),
          healthCard,
        ],
      ),
    );
  }
}

class _FinanceCard extends ConsumerWidget {
  const _FinanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expensesAsync = ref.watch(expensesThisMonthProvider);
    final budgetAsync = ref.watch(overallBudgetCentsProvider);

    final spentCents = expensesAsync.valueOrNull?.fold<int>(0, (sum, e) => sum + e.amountCents) ?? 0;
    final budgetCents = budgetAsync.valueOrNull;
    final ratio = budgetCents != null && budgetCents > 0 ? (spentCents / budgetCents).clamp(0.0, 1.0) : 0.0;
    final topCategory = _topCategory(expensesAsync.valueOrNull ?? const []);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('This month', style: theme.textTheme.bodySmall),
              Row(
                children: [
                  _IconTextButton(
                    icon: LucideIcons.wallet,
                    label: 'Budget',
                    onTap: () => showSetBudgetDialog(context, ref, currentCents: budgetCents),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _IconTextButton(
                    icon: LucideIcons.plus,
                    label: 'Add',
                    onTap: () => showAddExpenseSheet(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            budgetCents != null
                ? '\$${(spentCents / 100).toStringAsFixed(0)} of \$${(budgetCents / 100).toStringAsFixed(0)} budget'
                : '\$${(spentCents / 100).toStringAsFixed(0)} spent so far',
            style: theme.textTheme.titleLarge,
          ),
          if (budgetCents != null) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: AppColors.chipPeach,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            topCategory != null ? '$topCategory is your biggest category this month.' : 'No expenses logged yet this month.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String? _topCategory(List<ExpenseRow> expenses) {
    if (expenses.isEmpty) return null;
    final totals = <String, int>{};
    for (final e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amountCents;
    }
    return totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

class _HealthCard extends ConsumerWidget {
  const _HealthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goalsAsync = ref.watch(healthGoalsProvider);
    final todayAsync = ref.watch(healthTodayProvider);

    if (goalsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    final goals = goalsAsync.valueOrNull;
    if (goals == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set your goals to start tracking.', style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => showHealthGoalsDialog(context, ref),
              child: const Text('Set goals'),
            ),
          ],
        ),
      );
    }

    final today = todayAsync.valueOrNull ?? const HealthToday(waterCount: 0, workoutMinutes: 0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _HealthMetric(
                  icon: LucideIcons.droplets,
                  label: 'Water',
                  value: '${today.waterCount}/${goals.waterTarget}',
                ),
              ),
              Expanded(
                child: _HealthMetric(
                  icon: LucideIcons.moon,
                  label: 'Sleep',
                  value: today.sleepHours != null ? '${today.sleepHours}h' : '—',
                ),
              ),
              Expanded(
                child: _HealthMetric(
                  icon: LucideIcons.dumbbell,
                  label: 'Movement',
                  value: '${today.workoutMinutes}m',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _IconTextButton(
                icon: LucideIcons.plus,
                label: 'Water',
                onTap: () async {
                  final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
                  if (userId == null) return;
                  try {
                    await ref
                        .read(healthRepositoryProvider)
                        .logToday(userId: userId, waterCount: today.waterCount + 1);
                    ref.invalidate(healthTodayProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(friendlyError(e))),
                      );
                    }
                  }
                },
              ),
              const SizedBox(width: AppSpacing.md),
              _IconTextButton(
                icon: LucideIcons.notebookPen,
                label: 'Sleep & movement',
                onTap: () => showLogHealthSheet(context),
              ),
              const Spacer(),
              _IconTextButton(
                icon: LucideIcons.settings,
                label: 'Goals',
                onTap: () => showHealthGoalsDialog(
                  context,
                  ref,
                  waterTarget: goals.waterTarget,
                  sleepTargetHours: goals.sleepTargetHours,
                  workoutTargetMinutes: goals.workoutTargetMinutes,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthMetric extends StatelessWidget {
  const _HealthMetric({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: 22),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: theme.textTheme.titleMedium),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _IconTextButton extends StatelessWidget {
  const _IconTextButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(width: 4),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
