import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/plan.dart';
import '../../core/models/task_item.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/streak_check.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final plan = ref.watch(planProvider);
    final theme = Theme.of(context);
    final overLimit = !plan.isFull && tasks.length > plan.maxActiveTasks;

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks & habits')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        onPressed: () {},
        child: const Icon(LucideIcons.plus),
      ),
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
                overLimit
                    ? 'Basic Mom covers up to ${plan.maxActiveTasks} active items — upgrade for unlimited.'
                    : '${tasks.length} of ${plan.maxActiveTasks} active items used on Basic Mom.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _TaskRow(task: task),
            ),
        ],
      ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task});

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
          CategoryIconBadge(icon: task.category.icon, tint: task.category.tint),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    decoration: task.done ? TextDecoration.lineThrough : null,
                    color: task.done
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (task.dueTime != null) task.dueTime!,
                    if (task.isHabit) '${task.streakCount} day streak',
                  ].join('  •  '),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          StreakCheck(done: task.done, onTap: () => ref.read(tasksProvider.notifier).toggleDone(task.id)),
        ],
      ),
    );
  }
}
