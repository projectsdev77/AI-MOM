import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/service_providers.dart';
import '../../core/providers/track_providers.dart';
import '../../core/repositories/health_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/primary_button.dart';
import 'health_widgets.dart';

enum _Metric { water, sleep, exercise }

class HealthDetailScreen extends ConsumerWidget {
  const HealthDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goalsAsync = ref.watch(healthGoalsProvider);
    final todayAsync = ref.watch(healthTodayProvider);
    final activitiesAsync = ref.watch(healthActivitiesProvider);

    final goals = goalsAsync.valueOrNull;
    final today = todayAsync.valueOrNull ?? const HealthToday(waterCount: 0, workoutMinutes: 0);
    final activities = activitiesAsync.valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health tracking'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings, size: 20),
            tooltip: 'Goals',
            onPressed: () => showHealthGoalsDialog(
              context,
              ref,
              waterTarget: goals?.waterTarget ?? 8,
              sleepTargetHours: goals?.sleepTargetHours ?? 8,
              workoutTargetMinutes: goals?.workoutTargetMinutes ?? 30,
            ),
          ),
        ],
      ),
      body: goalsAsync.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : goalsAsync.hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.triangleAlert, size: 32, color: AppColors.moodDisappointed),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          friendlyError(goalsAsync.error!),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PrimaryButton(
                          label: 'Try again',
                          onPressed: () => ref.invalidate(healthGoalsProvider),
                        ),
                      ],
                    ),
                  ),
                )
              : goals == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Set your goals to start tracking.', style: theme.textTheme.bodyLarge),
                        const SizedBox(height: AppSpacing.md),
                        PrimaryButton(label: 'Set goals', onPressed: () => showHealthGoalsDialog(context, ref)),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _MetricCard(
                              metric: _Metric.water,
                              icon: LucideIcons.droplets,
                              tint: ChipTint.sage,
                              label: 'Water',
                              value: '${today.waterCount}',
                              goal: '${goals.waterTarget}',
                              onQuickAdd: () async {
                                final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
                                if (userId == null) return;
                                try {
                                  await ref
                                      .read(healthRepositoryProvider)
                                      .logToday(userId: userId, waterCount: today.waterCount + 1);
                                  ref.invalidate(healthTodayProvider);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(content: Text(friendlyError(e))));
                                  }
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _MetricCard(
                              metric: _Metric.sleep,
                              icon: LucideIcons.moon,
                              tint: ChipTint.blush,
                              label: 'Sleep',
                              value: today.sleepHours != null ? '${today.sleepHours}h' : '—',
                              goal: '${goals.sleepTargetHours}h',
                              onQuickAdd: () => showLogSleepSheet(context, ref),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _MetricCard(
                              metric: _Metric.exercise,
                              icon: LucideIcons.dumbbell,
                              tint: ChipTint.peach,
                              label: 'Exercise',
                              value: '${today.workoutMinutes}m',
                              goal: '${goals.workoutTargetMinutes}m',
                              onQuickAdd: () => showLogWorkoutSheet(context, ref),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Staying active', style: theme.textTheme.titleMedium),
                        IconButton(
                          icon: const Icon(LucideIcons.plus),
                          tooltip: 'Add activity',
                          onPressed: () => showAddHealthActivitySheet(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (activities.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Text(
                          'No custom activities yet — add one like "Tennis" or "Yoga" with its own daily goal.',
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                    else
                      for (final activity in activities)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _ActivityRow(activity: activity),
                        ),
                  ],
                ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.metric,
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    required this.goal,
    required this.onQuickAdd,
  });

  final _Metric metric;
  final IconData icon;
  final ChipTint tint;
  final String label;
  final String value;
  final String goal;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _MetricSummarySheet(metric: metric, label: label, value: value, goal: goal),
      ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CategoryIconBadge(icon: icon, tint: tint, size: 30),
                InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  onTap: onQuickAdd,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(LucideIcons.plus, size: 16, color: AppColors.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: theme.textTheme.titleMedium),
            Text('of $goal · $label', style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _MetricSummarySheet extends ConsumerWidget {
  const _MetricSummarySheet({required this.metric, required this.label, required this.value, required this.goal});
  final _Metric metric;
  final String label;
  final String value;
  final String goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSheet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('$value of $goal today', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Log $label',
            onPressed: () {
              Navigator.pop(context);
              switch (metric) {
                case _Metric.water:
                  showQuickLogDialog(
                    context,
                    ref,
                    title: 'Log water',
                    hint: 'Glasses of water',
                    isDecimal: false,
                    onSave: (v) async {
                      final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
                      if (userId == null) return;
                      await ref.read(healthRepositoryProvider).logToday(userId: userId, waterCount: v.toInt());
                      ref.invalidate(healthTodayProvider);
                    },
                  );
                case _Metric.sleep:
                  showLogSleepSheet(context, ref);
                case _Metric.exercise:
                  showLogWorkoutSheet(context, ref);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends ConsumerWidget {
  const _ActivityRow({required this.activity});
  final HealthActivity activity;

  Future<void> _confirmAndArchive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this activity?'),
        content: Text('"${activity.title}" and today\'s logged minutes will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.moodDisappointed)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      if (context.mounted) Slidable.of(context)?.close();
      return;
    }
    try {
      await ref.read(healthRepositoryProvider).archiveActivity(activity.id);
      ref.invalidate(healthActivitiesProvider);
    } catch (e) {
      if (context.mounted) {
        Slidable.of(context)?.close();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Slidable(
      key: ValueKey(activity.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (actionContext) => _confirmAndArchive(actionContext, ref),
            backgroundColor: AppColors.moodDisappointed,
            foregroundColor: Colors.white,
            icon: LucideIcons.trash2,
            borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
          border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight),
        ),
        child: Row(
          children: [
            CategoryIconBadge(icon: LucideIcons.activity, tint: ChipTint.tan, size: 36),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activity.title, style: theme.textTheme.bodyLarge),
                  Text(
                    '${activity.todayMinutes}/${activity.targetMinutes}min today',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              onTap: () => showLogActivityMinutesSheet(context, ref, activityId: activity.id, title: activity.title),
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.xs),
                child: Icon(LucideIcons.plus, color: AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
