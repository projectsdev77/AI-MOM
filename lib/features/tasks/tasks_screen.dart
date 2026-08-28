import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/plan.dart';
import '../../core/models/task_item.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_mood.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/mom_avatar.dart';
import '../../core/widgets/mom_components.dart';
import '../shell/app_shell.dart';
import 'add_task_sheet.dart';
import 'streak_celebration.dart';

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  void _quickAdd(BuildContext context, WidgetRef ref, List<TaskItem> allTasks, AppPlan plan) {
    if (!plan.isFull && allTasks.length >= plan.maxActiveTasks) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Basic Mom covers up to ${plan.maxActiveTasks} active items — upgrade for unlimited.')),
      );
      return;
    }
    showAddTaskSheet(context, forDay: ref.read(selectedTaskDayProvider));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    final allTasks = ref.watch(tasksProvider);
    final dayTasksAsync = ref.watch(tasksForSelectedDayProvider);
    final selectedDay = ref.watch(selectedTaskDayProvider);
    final plan = ref.watch(planProvider);
    final mood = ref.watch(momMoodProvider);
    final message = ref.watch(momMessageProvider);
    final momAvatar = ref.watch(effectiveMomAvatarProvider);
    final dayTasks = dayTasksAsync.valueOrNull ?? const <TaskItem>[];
    final isToday = _isSameDay(selectedDay, DateTime.now());
    final todayTasks = allTasks.where((t) => t.appliesToDay(DateTime.now())).toList();
    final completedToday = todayTasks.where((t) => t.done).length;

    final bestStreak = allTasks.where((t) => t.isHabit).fold<int>(0, (best, t) => t.streakCount > best ? t.streakCount : best);
    final activeItemsValue = plan.isFull ? '${allTasks.length}' : '${allTasks.length}/${plan.maxActiveTasks}';

    final healthTasks = plan.isFull ? dayTasks.where((t) => t.category == TaskCategory.health).toList() : const <TaskItem>[];
    final myTasks = plan.isFull ? dayTasks.where((t) => t.category != TaskCategory.health).toList() : dayTasks;

    return Scaffold(
      floatingActionButton: MomFab(tooltip: 'Add task', onPressed: () => _quickAdd(context, ref, allTasks, plan)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, AppSpacing.lg, AppSpacing.momGutter, 96),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tasks & habits', style: MomText.screenTitle(mom.ink)),
                      const SizedBox(height: 2),
                      Text(DateFormat('EEEE, MMMM d').format(DateTime.now()), style: MomText.body(mom.inkSoft)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                  decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill), boxShadow: MomElevation.card),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MomAvatar(style: momAvatar, mood: mood, showMoodBadge: false, size: 28),
                      const SizedBox(width: 8),
                      Text('$completedToday of ${todayTasks.length} done', style: MomText.meta(mom.ink)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.momSectionGap),
            const _TasksCalendarCard(),
            const SizedBox(height: AppSpacing.momSectionGap),
            MomMessageCard(avatarStyle: momAvatar, expression: MomExpression.mad, eyebrow: 'Keeping score', message: message),
            const SizedBox(height: AppSpacing.momSectionGap),
            Row(
              children: [
                Expanded(child: MomStatCard(icon: LucideIcons.check, tintIndex: 0, value: '$completedToday/${todayTasks.length}', caption: 'Done today')),
                const SizedBox(width: AppSpacing.momRowGap),
                Expanded(child: MomStatCard(icon: LucideIcons.flame, tintIndex: 1, value: '$bestStreak day${bestStreak == 1 ? '' : 's'}', caption: 'Best streak')),
                const SizedBox(width: AppSpacing.momRowGap),
                Expanded(child: MomStatCard(icon: LucideIcons.listChecks, tintIndex: 4, value: activeItemsValue, caption: 'Active items')),
              ],
            ),
            if (!plan.isFull) ...[
              const SizedBox(height: AppSpacing.momRowGap),
              _PlanUsageCard(activeCount: allTasks.length, maxActive: plan.maxActiveTasks),
            ],
            const SizedBox(height: AppSpacing.momSectionGap),
            Text(
              isToday ? "Today's list" : DateFormat('EEEE, MMM d').format(selectedDay),
              style: MomText.section(mom.ink),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (dayTasksAsync.isLoading && dayTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator(color: mom.espresso)),
              )
            else if (dayTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Text(
                  isToday ? 'Nothing on your list today.' : 'Nothing on the list for this day.',
                  style: MomText.body(mom.inkMuted),
                ),
              )
            else if (!plan.isFull)
              for (var i = 0; i < myTasks.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.momRowGap),
                  child: _TaskRow(task: myTasks[i], isToday: isToday, tintIndex: i),
                )
            else ...[
              if (myTasks.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text('My tasks', style: MomText.meta(mom.inkMuted, size: 12)),
                ),
                for (var i = 0; i < myTasks.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.momRowGap),
                    child: _TaskRow(task: myTasks[i], isToday: isToday, tintIndex: i),
                  ),
              ],
              if (healthTasks.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
                  child: Text('Health tracker', style: MomText.meta(mom.inkMuted, size: 12)),
                ),
                for (var i = 0; i < healthTasks.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.momRowGap),
                    child: _TaskRow(task: healthTasks[i], isToday: isToday, tintIndex: myTasks.length + i),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanUsageCard extends StatelessWidget {
  const _PlanUsageCard({required this.activeCount, required this.maxActive});
  final int activeCount;
  final int maxActive;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final overLimit = activeCount > maxActive;
    final ratio = maxActive > 0 ? (activeCount / maxActive).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard), boxShadow: MomElevation.card),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overLimit ? 'Basic Mom covers up to $maxActive active items.' : '$activeCount of $maxActive active items used on Basic Mom.',
                  style: MomText.meta(mom.inkSoft),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: mom.fieldBorder,
                    valueColor: AlwaysStoppedAnimation(mom.doneOrange),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          GestureDetector(
            onTap: () => context.push('/upgrade'),
            child: Text('Upgrade', style: MomText.control(mom.espresso)),
          ),
        ],
      ),
    );
  }
}

/// Week strip by default; tap the chevron to expand into a full month
/// grid. Tapping a day (either view) selects it, which filters the task
/// list below to whatever belongs on that day — see
/// [TaskItem.appliesToDay].
class _TasksCalendarCard extends ConsumerStatefulWidget {
  const _TasksCalendarCard();

  @override
  ConsumerState<_TasksCalendarCard> createState() => _TasksCalendarCardState();
}

class _TasksCalendarCardState extends ConsumerState<_TasksCalendarCard> {
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
    if (_expanded) setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final now = DateTime.now();
    final selectedDay = ref.watch(selectedTaskDayProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanelSm), boxShadow: MomElevation.card),
      child: Column(
        children: [
          Row(
            children: [
              if (_expanded) ...[
                IconButton(
                  icon: Icon(LucideIcons.chevronLeft, size: 18, color: mom.inkSoft),
                  onPressed: () => setState(() {
                    _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
                  }),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_displayedMonth),
                    textAlign: TextAlign.center,
                    style: MomText.rowSub(mom.ink),
                  ),
                ),
                IconButton(
                  icon: Icon(LucideIcons.chevronRight, size: 18, color: mom.inkSoft),
                  onPressed: () => setState(() {
                    _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
                  }),
                ),
              ] else
                const Spacer(),
              IconButton(
                icon: Icon(_expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 18, color: mom.inkMuted),
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
    final mom = context.mom;
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
              Expanded(child: Center(child: Text(label, style: MomText.meta(mom.inkMuted)))),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.85),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = DateTime(month.year, month.month, index - leadingBlanks + 1);
            return _DayCell(
              day: day,
              isToday: _isSameDay(day, now),
              isSelected: _isSameDay(day, selectedDay),
              onTap: () => onDayTap(day),
              showWeekdayLabel: false,
            );
          },
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
    this.showWeekdayLabel = true,
  });
  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showWeekdayLabel;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showWeekdayLabel) ...[
            Text(DateFormat('E').format(day).substring(0, 1), style: MomText.meta(isToday || isSelected ? mom.ink : mom.inkMuted)),
            const SizedBox(height: 6),
          ],
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? mom.ink : Colors.transparent,
              border: isToday && !isSelected ? Border.all(color: mom.fieldBorder, width: 2) : null,
            ),
            child: Text(
              '${day.day}',
              style: MomText.rowLabel(isSelected ? Colors.white : mom.inkSoft, selected: isToday || isSelected),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task, required this.isToday, required this.tintIndex});

  final TaskItem task;
  final bool isToday;
  final int tintIndex;

  /// Reveal-then-tap delete: swiping only opens the action pane (nothing
  /// is removed yet), a confirm dialog guards the actual deletion, and a
  /// cancel just closes the pane back up rather than deleting anything.
  Future<void> _confirmAndArchive(BuildContext context, WidgetRef ref) async {
    final mom = context.mom;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this task?'),
        content: Text('"${task.title}" will be removed from your list. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: mom.danger)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
    // Browsing a day other than today is read-only — only today's tasks
    // can be checked off.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Let's focus on today's tasks first — Mom")),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    return Slidable(
      key: ValueKey(task.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (actionContext) => _confirmAndArchive(actionContext, ref),
            backgroundColor: mom.danger,
            foregroundColor: Colors.white,
            icon: LucideIcons.trash2,
            borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
          ),
        ],
      ),
      child: MomTaskRow(
        icon: task.category.icon,
        tintIndex: tintIndex,
        metaLabel: task.categoryLabel,
        title: task.title,
        sub: task.dueTimeLabel ?? (task.isHabit ? '${task.streakCount} day streak' : null),
        done: task.done,
        onToggle: () => _toggle(context, ref),
      ),
    );
  }
}
