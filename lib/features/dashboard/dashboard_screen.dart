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
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_mood.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/widgets/mom_avatar.dart';
import '../../core/widgets/mom_components.dart';
import '../shell/app_shell.dart';
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
    final allDoneToday = tasks.isNotEmpty && completed == tasks.length;

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
                          color: mom.doneOrange,
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
            _WeekStripCard(allDoneToday: allDoneToday),
            const SizedBox(height: AppSpacing.momSectionGap),
            if (!plan.isFull)
              Row(
                children: [
                  Expanded(
                    child: MomStatCard(
                      icon: LucideIcons.flame,
                      tintIndex: 0,
                      value: '$completed/${tasks.length}',
                      caption: 'Tasks today',
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
              )
            else ...[
              MomStatCard(icon: LucideIcons.flame, tintIndex: 0, value: '$completed/${tasks.length}', caption: 'Tasks today'),
              const SizedBox(height: AppSpacing.momRowGap),
              _FinanceSummaryDashboardCard(
                spentCents: spentCents,
                budgetCents: budgetCents,
                currency: ref.watch(currencyProvider),
                onTap: goToFinanceOrUpgrade,
              ),
              const SizedBox(height: AppSpacing.momRowGap),
              _HealthSummaryDashboardCard(
                waterCount: waterCount,
                waterTarget: waterTarget,
                sleepHours: sleepHours,
                workoutMinutes: workoutMinutes,
                workoutTarget: workoutTarget,
                onTap: goToHealthOrUpgrade,
              ),
            ],
            const SizedBox(height: AppSpacing.momSectionGap),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Today's tasks", style: MomText.section(mom.ink)),
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
            for (var i = 0; i < today.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.momRowGap),
                child: _DashboardTaskRow(task: today[i], tintIndex: i),
              ),
          ],
        ),
      ),
    );
  }
}

/// Real dates, honestly limited: only today's completion is derived from
/// live data (all of today's tasks done), so only today ever shows a
/// dot. Other days show no dot rather than fabricating history the app
/// doesn't track per-day yet.
class _WeekStripCard extends StatefulWidget {
  const _WeekStripCard({required this.allDoneToday});
  final bool allDoneToday;

  @override
  State<_WeekStripCard> createState() => _WeekStripCardState();
}

class _WeekStripCardState extends State<_WeekStripCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));

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
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Icon(
                _expanded ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                size: 18,
                color: mom.inkMuted,
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final day in days)
                  _WeekDayColumn(
                    day: day,
                    isToday: DateUtils.isSameDay(day, now),
                    fullyDone: DateUtils.isSameDay(day, now) && widget.allDoneToday,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekDayColumn extends StatelessWidget {
  const _WeekDayColumn({required this.day, required this.isToday, required this.fullyDone});
  final DateTime day;
  final bool isToday;
  final bool fullyDone;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return Column(
      children: [
        Text(DateFormat('E').format(day).substring(0, 1), style: MomText.meta(isToday ? mom.ink : mom.inkMuted, size: 11)),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(shape: BoxShape.circle, color: isToday ? mom.ink : Colors.transparent),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: MomText.rowLabel(isToday ? Colors.white : mom.inkSoft, selected: isToday),
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
    final mom = context.mom;
    final ratio = budgetCents != null && budgetCents! > 0 ? (spentCents / budgetCents!).clamp(0.0, 1.0) : null;
    final remaining = budgetCents != null ? budgetCents! - spentCents : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: mom.surface,
          borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
          boxShadow: MomElevation.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: mom.tints[1], borderRadius: BorderRadius.circular(AppSpacing.momRadiusTile - 1)),
              child: Icon(LucideIcons.wallet, size: 17, color: mom.tintIcons[1]),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spent this month', style: MomText.meta(mom.inkMuted)),
                  const SizedBox(height: 2),
                  Text(formatMoney(spentCents, currency), style: MomText.statValue(mom.ink)),
                  if (remaining != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      remaining < 0
                          ? '${formatMoney(-remaining, currency)} over budget'
                          : '${formatMoney(remaining, currency)} left',
                      style: MomText.meta(remaining < 0 ? mom.danger : mom.inkMuted),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        backgroundColor: mom.peachOnPeach.withValues(alpha: 0.4),
                        valueColor: AlwaysStoppedAnimation(mom.doneOrange),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: () => showAddExpenseSheet(context),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(LucideIcons.plus, size: 18, color: mom.espresso),
              ),
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
    final mom = context.mom;
    final parts = <String>[
      if (waterTarget != null) 'Water ${waterCount ?? 0}/$waterTarget',
      if (sleepHours != null) 'Sleep ${sleepHours!.toStringAsFixed(1)}h',
      if (workoutTarget != null) 'Move ${workoutMinutes ?? 0}/$workoutTarget min',
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: mom.surface,
          borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
          boxShadow: MomElevation.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: mom.tints[4], borderRadius: BorderRadius.circular(AppSpacing.momRadiusTile - 1)),
              child: Icon(LucideIcons.droplets, size: 17, color: mom.tintIcons[4]),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Health today', style: MomText.meta(mom.inkMuted)),
                  const SizedBox(height: 2),
                  Text(
                    parts.isEmpty ? 'Set goals to start tracking' : parts.join('  •  '),
                    style: MomText.cardTitle(mom.ink),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _logWater(ref),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(LucideIcons.plus, size: 18, color: mom.espresso),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTaskRow extends ConsumerWidget {
  const _DashboardTaskRow({required this.task, required this.tintIndex});
  final TaskItem task;
  final int tintIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MomTaskRow(
      icon: task.category.icon,
      tintIndex: tintIndex,
      metaLabel: task.categoryLabel,
      title: task.title,
      sub: task.dueTimeLabel ?? (task.isHabit ? '${task.streakCount} day streak' : null),
      done: task.done,
      onToggle: () async {
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
    );
  }
}
