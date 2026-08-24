import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../core/models/plan.dart';
import '../../core/models/task_item.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/providers/calendar_providers.dart';
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

    final spentCents = expensesAsync.valueOrNull?.fold<int>(0, (sum, e) => sum + e.amountCents) ?? 0;
    final waterCount = healthTodayAsync.valueOrNull?.waterCount;
    final waterTarget = healthGoalsAsync.valueOrNull?.waterTarget;

    void goToTrackOrUpgrade() => plan.isFull ? context.go('/track') : context.push('/upgrade');

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
            const _DashboardCalendar(),
            const SizedBox(height: AppSpacing.xl),
            _MomMessageCard(mood: mood, message: message),
            const SizedBox(height: AppSpacing.xl),
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
                    onTap: goToTrackOrUpgrade,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _StatTile(
                    icon: LucideIcons.droplets,
                    tint: ChipTint.sage,
                    label: 'Water',
                    value: waterTarget != null ? '${waterCount ?? 0}/$waterTarget' : 'Log it',
                    onTap: goToTrackOrUpgrade,
                  ),
                ),
              ],
            ),
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

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Week strip by default; tap the chevron to expand into a full month
/// grid with real data — a dot on any day that has a completed task,
/// fetched from `task_completions`. Tapping a day (either view) opens a
/// sheet listing what was completed that day.
class _DashboardCalendar extends ConsumerStatefulWidget {
  const _DashboardCalendar();

  @override
  ConsumerState<_DashboardCalendar> createState() => _DashboardCalendarState();
}

class _DashboardCalendarState extends ConsumerState<_DashboardCalendar> {
  bool _expanded = false;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month, 1);
  }

  void _showDaySummary(DateTime day, List<String> titles) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _DaySummarySheet(day: day, titles: titles),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final completions = ref.watch(monthCompletionsProvider(_displayedMonth)).valueOrNull ?? const {};

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
            _MonthGrid(
              month: _displayedMonth,
              completions: completions,
              onDayTap: (day) => _showDaySummary(day, completions[_dateKey(day)] ?? const []),
            )
          else
            _WeekStrip(
              completions: completions,
              onDayTap: (day) => _showDaySummary(day, completions[_dateKey(day)] ?? const []),
            ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.completions, required this.onDayTap});
  final Map<String, List<String>> completions;
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
                hasCompletion: completions.containsKey(_dateKey(day)),
                onTap: () => onDayTap(day),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.completions, required this.onDayTap});
  final DateTime month;
  final Map<String, List<String>> completions;
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
              hasCompletion: completions.containsKey(_dateKey(day)),
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
  const _DayCell({required this.day, required this.isToday, required this.hasCompletion, required this.onTap});
  final DateTime day;
  final bool isToday;
  final bool hasCompletion;
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
              color: isToday ? theme.colorScheme.secondary : Colors.transparent,
            ),
            child: Text(
              '${day.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isToday ? theme.colorScheme.onSecondary : theme.colorScheme.onSurface,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 5,
            height: 5,
            child: hasCompletion
                ? DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent))
                : null,
          ),
        ],
      ),
    );
  }
}

class _DaySummarySheet extends StatelessWidget {
  const _DaySummarySheet({required this.day, required this.titles});
  final DateTime day;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
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
          Text(DateFormat('EEEE, MMMM d').format(day), style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          if (titles.isEmpty)
            Text('Nothing completed this day.', style: theme.textTheme.bodySmall)
          else
            for (final title in titles)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(LucideIcons.checkCircle2, size: 16, color: AppColors.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
        ],
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
                  updated.streakCount > 1 &&
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
