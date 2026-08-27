import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../core/models/plan.dart';
import '../../core/models/task_item.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/providers/currency_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/track_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_mood.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/mom_avatar.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/streak_check.dart';
import '../tasks/add_task_sheet.dart';
import '../tasks/streak_celebration.dart';
import '../track/finance_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final profileName = (profile?['name'] as String?)?.trim();
    final name = (profileName != null && profileName.isNotEmpty) ? profileName : 'there';
    final tasks = ref.watch(tasksProvider);
    final mood = ref.watch(momMoodProvider);
    final message = ref.watch(momMessageProvider);
    final momAvatar = ref.watch(effectiveMomAvatarProvider);
    final plan = ref.watch(planProvider);
    final expensesAsync = ref.watch(expensesThisMonthProvider);
    final healthTodayAsync = ref.watch(healthTodayProvider);
    final healthGoalsAsync = ref.watch(healthGoalsProvider);

    final budgetCentsAsync = ref.watch(overallBudgetCentsProvider);
    final spentCents = expensesAsync.valueOrNull?.fold<int>(0, (sum, e) => sum + e.amountCents) ?? 0;
    final budgetCents = budgetCentsAsync.valueOrNull;
    final waterCount = healthTodayAsync.valueOrNull?.waterCount;
    final waterTarget = healthGoalsAsync.valueOrNull?.waterTarget;
    final sleepHours = healthTodayAsync.valueOrNull?.sleepHours;
    final workoutMinutes = healthTodayAsync.valueOrNull?.workoutMinutes;
    final workoutTarget = healthGoalsAsync.valueOrNull?.workoutTargetMinutes;

    void goToFinanceOrUpgrade() => plan.isFull ? context.push('/track/finance') : context.push('/upgrade');
    void goToHealthOrUpgrade() => plan.isFull ? context.push('/track/health') : context.push('/upgrade');

    final today = tasks.take(4).toList();
    final completed = tasks.where((t) => t.done).length;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_greeting()}, $name', style: theme.textTheme.headlineLarge),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('EEEE, MMMM d').format(DateTime.now()),
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                MomAvatar(style: momAvatar, mood: mood, size: 52),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _MomMessageCard(mood: mood, message: message),
            const SizedBox(height: AppSpacing.xl),
            if (!plan.isFull)
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: LucideIcons.flame,
                      tint: ChipTint.peach,
                      label: 'Tasks today',
                      value: '$completed/${tasks.length}',
                      onTap: () => context.go('/tasks'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _StatTile(
                      icon: LucideIcons.wallet,
                      tint: ChipTint.tan,
                      label: 'Spent this month',
                      value: formatMoney(spentCents, ref.watch(currencyProvider)),
                      onTap: goToFinanceOrUpgrade,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _StatTile(
                      icon: LucideIcons.droplets,
                      tint: ChipTint.sage,
                      label: 'Water',
                      value: waterTarget != null ? '${waterCount ?? 0}/$waterTarget' : 'Log it',
                      onTap: goToHealthOrUpgrade,
                    ),
                  ),
                ],
              )
            else ...[
              _StatTile(
                icon: LucideIcons.flame,
                tint: ChipTint.peach,
                label: 'Tasks today',
                value: '$completed/${tasks.length}',
                onTap: () => context.go('/tasks'),
              ),
              const SizedBox(height: AppSpacing.md),
              _FinanceSummaryDashboardCard(
                spentCents: spentCents,
                budgetCents: budgetCents,
                currency: ref.watch(currencyProvider),
                onTap: goToFinanceOrUpgrade,
              ),
              const SizedBox(height: AppSpacing.md),
              _HealthSummaryDashboardCard(
                waterCount: waterCount,
                waterTarget: waterTarget,
                sleepHours: sleepHours,
                workoutMinutes: workoutMinutes,
                workoutTarget: workoutTarget,
                onTap: goToHealthOrUpgrade,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: "Today's tasks",
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.plus),
                    tooltip: 'Quick add task',
                    onPressed: () {
                      if (!plan.isFull && tasks.length >= plan.maxActiveTasks) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Basic Mom covers up to ${plan.maxActiveTasks} active items — upgrade for unlimited.')),
                        );
                        return;
                      }
                      showAddTaskSheet(context);
                    },
                  ),
                  TextButton(
                    onPressed: () => context.go('/tasks'),
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final task in today)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _DashboardTaskRow(task: task),
              ),
          ],
        ),
      ),
    );
  }
}

class _MomMessageCard extends StatelessWidget {
  const _MomMessageCard({required this.mood, required this.message});
  final MomMood mood;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
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
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: mood.color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(mood.label, style: theme.textTheme.labelSmall?.copyWith(color: mood.color)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final ChipTint tint;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryIconBadge(icon: icon, tint: tint, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: theme.textTheme.titleMedium),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// Full-plan replacement for the small "Spent this month" tile — a real
/// budget summary (same numbers as the Finance detail page, condensed)
/// with a quick way to log an expense without leaving the Dashboard.
class _FinanceSummaryDashboardCard extends StatelessWidget {
  const _FinanceSummaryDashboardCard({
    required this.spentCents,
    required this.budgetCents,
    required this.currency,
    required this.onTap,
  });

  final int spentCents;
  final int? budgetCents;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = budgetCents != null && budgetCents! > 0 ? (spentCents / budgetCents!).clamp(0.0, 1.0) : null;
    final remaining = budgetCents != null ? budgetCents! - spentCents : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryIconBadge(icon: LucideIcons.wallet, tint: ChipTint.tan, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spent this month', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 2),
                  Text(formatMoney(spentCents, currency), style: theme.textTheme.titleMedium),
                  if (remaining != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      remaining < 0
                          ? '${formatMoney(-remaining, currency)} over budget'
                          : '${formatMoney(remaining, currency)} left',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: remaining < 0 ? AppColors.moodDisappointed : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        backgroundColor: AppColors.chipPeach,
                        valueColor: AlwaysStoppedAnimation(
                          (ratio ?? 0) >= 1 ? AppColors.moodDisappointed : AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.plus),
              tooltip: 'Add expense',
              onPressed: () => showAddExpenseSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-plan replacement for the small "Water" tile — a real summary
/// across water/sleep/movement with a quick +1 water log, mirroring the
/// same one-tap pattern used on the Health detail page.
class _HealthSummaryDashboardCard extends ConsumerWidget {
  const _HealthSummaryDashboardCard({
    required this.waterCount,
    required this.waterTarget,
    required this.sleepHours,
    required this.workoutMinutes,
    required this.workoutTarget,
    required this.onTap,
  });

  final int? waterCount;
  final int? waterTarget;
  final double? sleepHours;
  final int? workoutMinutes;
  final int? workoutTarget;
  final VoidCallback onTap;

  Future<void> _logWater(WidgetRef ref) async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    await ref.read(healthRepositoryProvider).logToday(userId: userId, waterCount: (waterCount ?? 0) + 1);
    ref.invalidate(healthTodayProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final parts = <String>[
      if (waterTarget != null) 'Water ${waterCount ?? 0}/$waterTarget',
      if (sleepHours != null) 'Sleep ${sleepHours!.toStringAsFixed(1)}h',
      if (workoutTarget != null) 'Move ${workoutMinutes ?? 0}/$workoutTarget min',
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryIconBadge(icon: LucideIcons.droplets, tint: ChipTint.sage, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Health today', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 2),
                  Text(
                    parts.isEmpty ? 'Set goals to start tracking' : parts.join('  •  '),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.plus),
              tooltip: 'Log a glass of water',
              onPressed: () => _logWater(ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTaskRow extends ConsumerWidget {
  const _DashboardTaskRow({required this.task});
  final TaskItem task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
        border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight),
      ),
      child: Row(
        children: [
          CategoryIconBadge(icon: task.category.icon, tint: task.category.tint, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              task.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: task.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          StreakCheck(
            done: task.done,
            size: 24,
            onTap: () async {
              final wasDone = task.done;
              final updated = await ref.read(tasksProvider.notifier).toggleDone(task.id);
              if (updated != null &&
                  !wasDone &&
                  updated.done &&
                  updated.isHabit &&
                  updated.streakCount >= 1 &&
                  context.mounted) {
                showStreakCelebration(context, taskTitle: updated.title, streakCount: updated.streakCount);
              }
            },
          ),
        ],
      ),
    );
  }
}
