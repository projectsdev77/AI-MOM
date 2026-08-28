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
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/widgets/mom_avatar.dart';
import '../../core/widgets/mom_components.dart';
import '../shell/app_shell.dart';
import '../tasks/add_task_sheet.dart';
import '../tasks/streak_celebration.dart';

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  void _quickAddTask(BuildContext context, WidgetRef ref, List<TaskItem> tasks, AppPlan plan) {
    if (!plan.isFull && tasks.length >= plan.maxActiveTasks) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Basic Mom covers up to ${plan.maxActiveTasks} active items — upgrade for unlimited.')),
      );
      return;
    }
    showAddTaskSheet(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    final profile = ref.watch(profileProvider).valueOrNull;
    final profileName = (profile?['name'] as String?)?.trim();
    final name = (profileName != null && profileName.isNotEmpty) ? profileName : 'there';
    final tasks = ref.watch(tasksProvider);
    final selectedDay = ref.watch(selectedTaskDayProvider);
    final selectedDayTasksAsync = ref.watch(tasksForSelectedDayProvider);
    final isToday = _isSameDay(selectedDay, DateTime.now());
    final mood = ref.watch(momMoodProvider);
    final message = ref.watch(momMessageProvider);
    final momAvatar = ref.watch(effectiveMomAvatarProvider);
    final plan = ref.watch(planProvider);
    final expensesAsync = ref.watch(expensesThisMonthProvider);
    final healthTodayAsync = ref.watch(healthTodayProvider);
    final healthGoalsAsync = ref.watch(healthGoalsProvider);

    final spentCents = expensesAsync.valueOrNull?.fold<int>(0, (sum, e) => sum + e.amountCents) ?? 0;
    final waterCount = healthTodayAsync.valueOrNull?.waterCount;
    final waterTarget = healthGoalsAsync.valueOrNull?.waterTarget;

    void goToFinanceOrUpgrade() => plan.isFull ? context.push('/track/finance') : context.push('/upgrade');
    void goToHealthOrUpgrade() => plan.isFull ? context.push('/track/health') : context.push('/upgrade');

    final selectedDayTasks = selectedDayTasksAsync.valueOrNull ?? const <TaskItem>[];
    final completed = tasks.where((t) => t.done).length;
    final moodDotColor = switch (mood) {
      MomMood.proud => AppColors.moodHappy,
      MomMood.neutral => mom.doneOrange,
      MomMood.disappointed || MomMood.veryDisappointed => AppColors.moodVeryDisappointed,
    };

    return Scaffold(
      floatingActionButton: MomFab(
        tooltip: 'Quick add task',
        onPressed: () => _quickAddTask(context, ref, tasks, plan),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.momGutter,
            AppSpacing.lg,
            AppSpacing.momGutter,
            96,
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_greeting()}, $name', style: MomText.screenTitle(mom.ink)),
                      const SizedBox(height: 2),
                      Text(DateFormat('EEEE, MMMM d').format(DateTime.now()), style: MomText.body(mom.inkSoft)),
                    ],
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: mom.surface),
                      child: MomAvatar(style: momAvatar, mood: mood, showMoodBadge: false, size: 49),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: moodDotColor,
                          border: Border.all(color: mom.shell, width: 2.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.momSectionGap),
            MomMessageCard(avatarStyle: momAvatar, expression: mood.expression, eyebrow: mood.label, message: message),
            const SizedBox(height: AppSpacing.momSectionGap),
            const _WeekStripCard(),
            const SizedBox(height: AppSpacing.momSectionGap),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.go('/tasks'),
                    child: MomStatCard(
                      icon: LucideIcons.flame,
                      tintIndex: 0,
                      value: '$completed/${tasks.length}',
                      caption: 'Tasks today',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.momRowGap),
                Expanded(
                  child: GestureDetector(
                    onTap: goToFinanceOrUpgrade,
                    child: MomStatCard(
                      icon: LucideIcons.wallet,
                      tintIndex: 1,
                      value: formatMoney(spentCents, ref.watch(currencyProvider)),
                      caption: 'Spent this month',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.momRowGap),
                Expanded(
                  child: GestureDetector(
                    onTap: goToHealthOrUpgrade,
                    child: MomStatCard(
                      icon: LucideIcons.droplets,
                      tintIndex: 4,
                      value: waterTarget != null ? '${waterCount ?? 0}/$waterTarget' : 'Log it',
                      caption: 'Water',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.momSectionGap),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isToday ? "Today's tasks" : DateFormat('EEEE, MMM d').format(selectedDay),
                  style: MomText.section(mom.ink),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _quickAddTask(context, ref, tasks, plan),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(LucideIcons.plus, size: 18, color: mom.espresso),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => context.go('/tasks'),
                      child: Text('See all', style: MomText.control(mom.espresso)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (selectedDayTasksAsync.isLoading && selectedDayTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator(color: mom.espresso)),
              )
            else if (selectedDayTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  isToday ? 'Nothing on your list today.' : 'Nothing on the list for this day.',
                  style: MomText.body(mom.inkMuted),
                ),
              )
            else
              for (var i = 0; i < selectedDayTasks.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.momRowGap),
                  child: _DashboardTaskRow(task: selectedDayTasks[i], tintIndex: i, day: selectedDay, isToday: isToday),
                ),
          ],
        ),
      ),
    );
  }
}

/// Week strip by default; tap the chevron to expand into a full month
/// grid — same pattern as the Tasks screen's calendar. Tapping a day
/// (either view) selects it via the shared selectedTaskDayProvider,
/// which filters the task list below. Only today's "fully done" dot is
/// derived from live data; other days show no dot rather than
/// fabricating history the app doesn't track per-day.
class _WeekStripCard extends ConsumerStatefulWidget {
  const _WeekStripCard();

  @override
  ConsumerState<_WeekStripCard> createState() => _WeekStripCardState();
}

class _WeekStripCardState extends ConsumerState<_WeekStripCard> {
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
    final mom = context.mom;
    final now = DateTime.now();
    final selectedDay = ref.watch(selectedTaskDayProvider);
    final tasks = ref.watch(tasksProvider);
    final allDoneToday = tasks.isNotEmpty && tasks.every((t) => t.done);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: mom.surface,
        borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanelSm),
        boxShadow: MomElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            _MonthGrid(month: _displayedMonth, selectedDay: selectedDay, allDoneToday: allDoneToday, onDayTap: _selectDay)
          else
            _WeekStrip(selectedDay: selectedDay, allDoneToday: allDoneToday, onDayTap: _selectDay),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.selectedDay, required this.allDoneToday, required this.onDayTap});
  final DateTime selectedDay;
  final bool allDoneToday;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final day in days)
          _WeekDayColumn(
            day: day,
            isSelected: _isSameDay(day, selectedDay),
            fullyDone: _isSameDay(day, now) && allDoneToday,
            onTap: () => onDayTap(day),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.selectedDay, required this.allDoneToday, required this.onDayTap});
  final DateTime month;
  final DateTime selectedDay;
  final bool allDoneToday;
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = DateTime(month.year, month.month, index - leadingBlanks + 1);
            return _WeekDayColumn(
              day: day,
              isSelected: _isSameDay(day, selectedDay),
              fullyDone: _isSameDay(day, now) && allDoneToday,
              onTap: () => onDayTap(day),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}

class _WeekDayColumn extends StatelessWidget {
  const _WeekDayColumn({required this.day, required this.isSelected, required this.fullyDone, required this.onTap});
  final DateTime day;
  final bool isSelected;
  final bool fullyDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final isToday = _isSameDay(day, DateTime.now());
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(DateFormat('E').format(day).substring(0, 1), style: MomText.meta(isToday || isSelected ? mom.ink : mom.inkMuted, size: 11)),
          const SizedBox(height: 6),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? mom.ink : Colors.transparent,
              border: isToday && !isSelected ? Border.all(color: mom.fieldBorder, width: 2) : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: MomText.rowLabel(isSelected ? Colors.white : mom.inkSoft, selected: isToday || isSelected),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fullyDone ? mom.doneOrange : (isToday ? mom.fieldBorder : Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardTaskRow extends ConsumerWidget {
  const _DashboardTaskRow({required this.task, required this.tintIndex, required this.day, required this.isToday});
  final TaskItem task;
  final int tintIndex;
  final DateTime day;
  final bool isToday;

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
    // A day other than today: just flip that day's completion row - no
    // optimistic streak/celebration UI, since a streak is inherently
    // about consecutive days ending today, not a retroactive edit. Same
    // rule the Tasks screen follows for the identical case.
    final ok = await ref.read(tasksProvider.notifier).setDoneForDay(id: task.id, day: day, done: !task.done);
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
    return MomTaskRow(
      icon: task.category.icon,
      tintIndex: tintIndex,
      metaLabel: task.categoryLabel,
      title: task.title,
      sub: task.dueTimeLabel ?? (task.isHabit ? '${task.streakCount} day streak' : null),
      done: task.done,
      onToggle: () => _toggle(context, ref),
    );
  }
}
