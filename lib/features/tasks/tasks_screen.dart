import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/plan.dart';
import '../../core/models/task_item.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/streak_check.dart';
import 'add_task_sheet.dart';
import 'streak_celebration.dart';

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(tasksProvider);
    final dayTasksAsync = ref.watch(tasksForSelectedDayProvider);
    final selectedDay = ref.watch(selectedTaskDayProvider);
    final plan = ref.watch(planProvider);
    final theme = Theme.of(context);
    final overLimit = !plan.isFull && allTasks.length > plan.maxActiveTasks;
    final dayTasks = dayTasksAsync.valueOrNull ?? const <TaskItem>[];
    final isToday = _isSameDay(selectedDay, DateTime.now());

    final healthTasks = plan.isFull ? dayTasks.where((t) => t.category == TaskCategory.health).toList() : const <TaskItem>[];
    final myTasks = plan.isFull ? dayTasks.where((t) => t.category != TaskCategory.health).toList() : dayTasks;

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks & habits')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        onPressed: () {
          if (!plan.isFull && allTasks.length >= plan.maxActiveTasks) {
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
          const _TasksCalendar(),
          const SizedBox(height: AppSpacing.lg),
          if (!plan.isFull)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                overLimit
                    ? 'Basic Mom covers up to ${plan.maxActiveTasks} active items — upgrade for unlimited.'
                    : '${allTasks.length} of ${plan.maxActiveTasks} active items used on Basic Mom.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (dayTasksAsync.isLoading && dayTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
            )
          else if (dayTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                isToday ? 'Nothing on your list today.' : 'Nothing on the list for this day.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else if (!plan.isFull)
            for (final task in myTasks)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _TaskRow(task: task, day: selectedDay, isToday: isToday),
              )
          else ...[
            if (myTasks.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text('My Tasks', style: theme.textTheme.titleSmall),
              ),
              for (final task in myTasks)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _TaskRow(task: task, day: selectedDay, isToday: isToday),
                ),
            ],
            if (healthTasks.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
                child: Text('Health Tracker', style: theme.textTheme.titleSmall),
              ),
              for (final task in healthTasks)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _TaskRow(task: task, day: selectedDay, isToday: isToday),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Week strip by default; tap the chevron to expand into a full month
/// grid. Tapping a day (either view) selects it, which filters the task
/// list below to whatever belongs on that day — see
/// [TaskItem.appliesToDay].
class _TasksCalendar extends ConsumerStatefulWidget {
  const _TasksCalendar();

  @override
  ConsumerState<_TasksCalendar> createState() => _TasksCalendarState();
}

class _TasksCalendarState extends ConsumerState<_TasksCalendar> {
  bool _expanded = false;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month, 1);
  }

  void _selectDay(DateTime day) {
    ref.read(selectedTaskDayProvider.notifier).state = DateTime(day.year, day.month, day.day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final selectedDay = ref.watch(selectedTaskDayProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (_expanded) ...[
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft, size: 18),
                  onPressed: () => setState(() {
                    _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
                  }),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_displayedMonth),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight, size: 18),
                  onPressed: () => setState(() {
                    _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
                  }),
                ),
              ] else
                const Spacer(),
              IconButton(
                icon: Icon(_expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 18),
                tooltip: _expanded ? 'Show week' : 'Show month',
                onPressed: () => setState(() {
                  _expanded = !_expanded;
                  if (_expanded) _displayedMonth = DateTime(now.year, now.month, 1);
                }),
              ),
            ],
          ),
          if (_expanded)
            _MonthGrid(month: _displayedMonth, selectedDay: selectedDay, onDayTap: _selectDay)
          else
            _WeekStrip(selectedDay: selectedDay, onDayTap: _selectDay),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.selectedDay, required this.onDayTap});
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return SizedBox(
      height: 64,
      child: Row(
        children: [
          for (final day in days)
            Expanded(
              child: _DayCell(
                day: day,
                isToday: _isSameDay(day, now),
                isSelected: _isSameDay(day, selectedDay),
                onTap: () => onDayTap(day),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.selectedDay, required this.onDayTap});
  final DateTime month;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstDay.weekday - 1; // Monday-first week

    return Column(
      children: [
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(child: Text(label, style: theme.textTheme.labelSmall)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = DateTime(month.year, month.month, index - leadingBlanks + 1);
            return _DayCell(
              day: day,
              isToday: _isSameDay(day, now),
              isSelected: _isSameDay(day, selectedDay),
              onTap: () => onDayTap(day),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.isToday, required this.isSelected, required this.onTap});
  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('E').format(day).substring(0, 1),
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? AppColors.accent
                  : (isToday ? theme.colorScheme.secondary : Colors.transparent),
              border: isSelected && isToday
                  ? Border.all(color: theme.colorScheme.secondary, width: 2)
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? Colors.white
                    : (isToday ? theme.colorScheme.onSecondary : theme.colorScheme.onSurface),
                fontWeight: (isToday || isSelected) ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task, required this.day, required this.isToday});

  final TaskItem task;
  final DateTime day;
  final bool isToday;

  /// Reveal-then-tap delete: swiping only opens the action pane (nothing
  /// is removed yet), a confirm dialog guards the actual deletion, and a
  /// cancel just closes the pane back up rather than deleting anything.
  Future<void> _confirmAndArchive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this task?'),
        content: Text('"${task.title}" will be removed from your list. This can\'t be undone.'),
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
      await ref.read(tasksProvider.notifier).archiveTask(task.id);
      ref.invalidate(tasksForSelectedDayProvider);
    } catch (e) {
      if (context.mounted) {
        Slidable.of(context)?.close();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    if (isToday) {
      final wasDone = task.done;
      final updated = await ref.read(tasksProvider.notifier).toggleDone(task.id);
      ref.invalidate(tasksForSelectedDayProvider);
      if (updated != null &&
          !wasDone &&
          updated.done &&
          updated.isHabit &&
          updated.streakCount >= 1 &&
          context.mounted) {
        showStreakCelebration(context, taskTitle: updated.title, streakCount: updated.streakCount);
      }
      return;
    }
    // A day other than today: just flip that day's completion row —
    // no optimistic streak/celebration UI, since a streak is inherently
    // about consecutive days ending today, not a retroactive edit.
    final ok = await ref
        .read(tasksProvider.notifier)
        .setDoneForDay(id: task.id, day: day, done: !task.done);
    if (ok) {
      ref.invalidate(tasksForSelectedDayProvider);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong on our end. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Slidable(
      key: ValueKey(task.id),
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
                      if (task.dueTimeLabel != null) task.dueTimeLabel!,
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
