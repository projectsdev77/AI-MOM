import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/app_state_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/track_providers.dart';
import '../../core/repositories/health_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_mood.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/mom_components.dart';
import '../../core/widgets/primary_button.dart';
import 'health_widgets.dart';

const _activitySuggestions = ['Tennis', 'Yoga', 'Walking'];

class HealthDetailScreen extends ConsumerWidget {
  const HealthDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    final momAvatar = ref.watch(effectiveMomAvatarProvider);
    final goalsAsync = ref.watch(healthGoalsProvider);
    final todayAsync = ref.watch(healthTodayProvider);
    final activitiesAsync = ref.watch(healthActivitiesProvider);

    if (goalsAsync.isLoading) {
      return Scaffold(
        backgroundColor: mom.shell,
        appBar: _healthAppBar(context, mom),
        body: Center(child: CircularProgressIndicator(color: mom.espresso)),
      );
    }

    if (goalsAsync.hasError) {
      return Scaffold(
        backgroundColor: mom.shell,
        appBar: _healthAppBar(context, mom),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.triangleAlert, size: 32, color: mom.danger),
                const SizedBox(height: AppSpacing.md),
                Text(friendlyError(goalsAsync.error!), textAlign: TextAlign.center, style: MomText.body(mom.ink)),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(label: 'Try again', onPressed: () => ref.invalidate(healthGoalsProvider)),
              ],
            ),
          ),
        ),
      );
    }

    final goals = goalsAsync.value;
    final today = todayAsync.valueOrNull ?? const HealthToday(waterCount: 0, workoutMinutes: 0);
    final activities = activitiesAsync.valueOrNull ?? const [];
    // "Exercise" is the day's total moving time — logged workouts plus
    // every "Staying active" activity's minutes — not just whichever one
    // was logged most recently.
    final activityMinutes = activities.fold<int>(0, (sum, a) => sum + a.todayMinutes);
    final totalExerciseMinutes = today.workoutMinutes + activityMinutes;

    if (goals == null) {
      return Scaffold(
        backgroundColor: mom.shell,
        appBar: _healthAppBar(context, mom),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Set your goals to start tracking.', style: MomText.body(mom.ink)),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(label: 'Set goals', onPressed: () => showHealthGoalsDialog(context, ref)),
              ],
            ),
          ),
        ),
      );
    }

    final needsAttention = today.waterCount == 0
        ? 'Water'
        : today.sleepHours == null
            ? 'Sleep'
            : totalExerciseMinutes == 0
                ? 'Exercise'
                : null;

    return Scaffold(
      backgroundColor: mom.shell,
      appBar: AppBar(
        backgroundColor: mom.shell,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, size: 22, color: mom.espresso),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Health tracking', style: MomText.cardTitle(mom.ink)),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.settings, size: 20, color: mom.inkSoft),
            tooltip: 'Goals',
            onPressed: () => showHealthGoalsDialog(
              context,
              ref,
              waterTarget: goals.waterTarget,
              sleepTargetHours: goals.sleepTargetHours,
              workoutTargetMinutes: goals.workoutTargetMinutes,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, AppSpacing.sm, AppSpacing.momGutter, 96),
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: LucideIcons.droplets,
                    tintIndex: 4,
                    label: 'Water',
                    value: '${today.waterCount}',
                    goal: '${goals.waterTarget}',
                    progress: (today.waterCount / goals.waterTarget).clamp(0.0, 1.0),
                    onQuickAdd: () => showLogWaterDialog(context, ref, currentCount: today.waterCount),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MetricCard(
                    icon: LucideIcons.moon,
                    tintIndex: 2,
                    label: 'Sleep',
                    value: today.sleepHours != null ? '${today.sleepHours}h' : '—',
                    goal: '${goals.sleepTargetHours}h',
                    progress: today.sleepHours != null ? (today.sleepHours! / goals.sleepTargetHours).clamp(0.0, 1.0) : 0.0,
                    onQuickAdd: () => showLogSleepSheet(context, ref),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MetricCard(
                    icon: LucideIcons.dumbbell,
                    tintIndex: 0,
                    label: 'Exercise',
                    value: '${totalExerciseMinutes}m',
                    goal: '${goals.workoutTargetMinutes}m',
                    progress: (totalExerciseMinutes / goals.workoutTargetMinutes).clamp(0.0, 1.0),
                    onQuickAdd: () => showLogWorkoutSheet(context, ref),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.momSectionGap),
          MomMessageCard(
            avatarStyle: momAvatar,
            expression: MomExpression.normal,
            eyebrow: 'Gentle reminder',
            message: needsAttention != null
                ? "$needsAttention hasn't been logged today yet — no rush, just don't forget."
                : "Everything's logged for today. Look at you.",
          ),
          const SizedBox(height: AppSpacing.momSectionGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Staying active', style: MomText.section(mom.ink)),
              GestureDetector(
                onTap: () => showAddHealthActivitySheet(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusTile), boxShadow: MomElevation.card),
                  child: Icon(LucideIcons.plus, size: 18, color: mom.espresso),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (activities.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard)),
              child: Text(
                'No custom activities yet — add one like "Tennis" or "Yoga" with its own daily goal.',
                style: MomText.body(mom.inkMuted),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final s in _activitySuggestions)
                  MomDashedChip(label: s, onTap: () => showAddHealthActivitySheet(context, initialTitle: s)),
              ],
            ),
          ] else
            for (var i = 0; i < activities.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.momRowGap),
                child: _ActivityRow(activity: activities[i], tintIndex: i),
              ),
        ],
      ),
    );
  }
}

AppBar _healthAppBar(BuildContext context, MomColors mom) => AppBar(
      backgroundColor: mom.shell,
      elevation: 0,
      leading: IconButton(
        icon: Icon(LucideIcons.chevronLeft, size: 22, color: mom.espresso),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text('Health tracking', style: MomText.cardTitle(mom.ink)),
    );

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.tintIndex,
    required this.label,
    required this.value,
    required this.goal,
    required this.progress,
    required this.onQuickAdd,
  });

  final IconData icon;
  final int tintIndex;
  final String label;
  final String value;
  final String goal;
  final double progress;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final tint = mom.tints[tintIndex % mom.tints.length];
    final tintIcon = mom.tintIcons[tintIndex % mom.tintIcons.length];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard), boxShadow: MomElevation.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppSpacing.momRadiusTile - 1)),
                child: Icon(icon, size: 17, color: tintIcon),
              ),
              GestureDetector(
                onTap: onQuickAdd,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: Icon(LucideIcons.plus, size: 18, color: mom.espresso),
                ),
              ),
            ],
          ),
          Text(value, style: MomText.metricValue(mom.ink)),
          const SizedBox(height: 2),
          Text('of $goal · $label', style: MomText.meta(mom.inkMuted)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
            child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: mom.hairline, valueColor: AlwaysStoppedAnimation(mom.doneOrange)),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends ConsumerWidget {
  const _ActivityRow({required this.activity, required this.tintIndex});
  final HealthActivity activity;
  final int tintIndex;

  Future<void> _confirmAndArchive(BuildContext context, WidgetRef ref) async {
    final mom = context.mom;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this activity?'),
        content: Text('"${activity.title}" and today\'s logged minutes will be removed.'),
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
    final mom = context.mom;
    final tint = mom.tints[tintIndex % mom.tints.length];
    final tintIcon = mom.tintIcons[tintIndex % mom.tintIcons.length];
    final progress = (activity.todayMinutes / activity.targetMinutes).clamp(0.0, 1.0);
    final overMinutes = activity.todayMinutes - activity.targetMinutes;
    return Slidable(
      key: ValueKey(activity.id),
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
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard), boxShadow: MomElevation.card),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppSpacing.momRadiusTile)),
              child: Icon(LucideIcons.activity, size: 18, color: tintIcon),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(activity.title, style: MomText.rowLabel(mom.ink)),
                  Text('${activity.todayMinutes}/${activity.targetMinutes}min today', style: MomText.rowSub(mom.inkMuted)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: mom.hairline,
                      valueColor: AlwaysStoppedAnimation(mom.doneOrange),
                    ),
                  ),
                  if (overMinutes > 0) ...[
                    const SizedBox(height: 4),
                    Text('${overMinutes}m over goal — look at you!', style: MomText.meta(mom.doneOrange)),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: () => showLogActivityMinutesSheet(context, ref, activityId: activity.id, title: activity.title),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                child: Icon(LucideIcons.plus, size: 18, color: mom.espresso),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
