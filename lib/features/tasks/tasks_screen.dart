import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/plan.dart';
import '../../core/models/task_item.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/streak_check.dart';
import 'add_task_sheet.dart';
import 'streak_celebration.dart';

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
        onPressed: () {
          if (!plan.isFull && tasks.length >= plan.maxActiveTasks) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Basic Mom covers up to ${plan.maxActiveTasks} active items — upgrade for unlimited.')),
            );
            return;
          }
          showAddTaskSheet(context);
        },
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

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(tasksProvider.notifier).archiveTask(task.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't archive that: $e")),
        );
      }
    }
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final wasDone = task.done;
    final updated = await ref.read(tasksProvider.notifier).toggleDone(task.id);
    if (updated != null &&
        !wasDone &&
        updated.done &&
        updated.isHabit &&
        updated.streakCount > 1 &&
        context.mounted) {
      showStreakCelebration(context, taskTitle: updated.title, streakCount: updated.streakCount);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Archive this task?'),
                content: Text('"${task.title}" will be removed from your list.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Archive', style: TextStyle(color: AppColors.moodDisappointed)),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => _archive(context, ref),
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.moodDisappointed,
          borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
        ),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
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
                      task.categoryLabel,
                      if (task.dueTime != null) task.dueTime!,
                      if (task.isHabit) '${task.streakCount} day streak',
                    ].join('  •  '),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            StreakCheck(done: task.done, onTap: () => _toggle(context, ref)),
          ],
        ),
      ),
    );
  }
}
