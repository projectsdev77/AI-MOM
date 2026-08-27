import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/app_state_provider.dart';
import '../../core/providers/currency_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/track_providers.dart';
import '../../core/repositories/health_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_mood.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/widgets/mom_avatar.dart';
import '../../core/widgets/mom_components.dart';
import 'finance_widgets.dart';

/// A summary of both trackers — tap either card for the real, detailed
/// page (`/track/finance`, `/track/health`). Kept deliberately light:
/// this screen's job is "what's the state of things," not editing.
class TrackScreen extends ConsumerWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    return Scaffold(body: plan.isFull ? const _TrackFull() : const _TrackLocked());
  }
}

class _TrackFull extends ConsumerWidget {
  const _TrackFull();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    final momAvatar = ref.watch(effectiveMomAvatarProvider);
    final currency = ref.watch(currencyProvider);
    final expenses = ref.watch(expensesThisMonthProvider).valueOrNull ?? const [];
    final budgetCents = ref.watch(overallBudgetCentsProvider).valueOrNull;
    final spentCents = expenses.fold<int>(0, (sum, e) => sum + e.amountCents);
    final goals = ref.watch(healthGoalsProvider).valueOrNull;
    final today = ref.watch(healthTodayProvider).valueOrNull;

    final spentByCategory = <String, int>{};
    for (final e in expenses) {
      spentByCategory[e.category] = (spentByCategory[e.category] ?? 0) + e.amountCents;
    }
    final biggestCategory = spentByCategory.isEmpty
        ? null
        : (spentByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;

    final momMessage = budgetCents != null && spentCents > budgetCents
        ? "You're ${formatMoney(spentCents - budgetCents, currency)} over this month${biggestCategory != null ? ' — mostly $biggestCategory' : ''}."
        : (goals != null && (today?.waterCount ?? 0) == 0
            ? "Nothing logged on the health side yet today. Small sips count."
            : "Money and body, both looking steady. Keep it up.");

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, AppSpacing.lg, AppSpacing.momGutter, 96),
        children: [
          Text('Track', style: MomText.screenTitle(mom.ink)),
          const SizedBox(height: 2),
          Text('${DateFormat('MMMM').format(DateTime.now())} · money and body', style: MomText.body(mom.inkSoft)),
          const SizedBox(height: AppSpacing.momSectionGap),
          MomMessageCard(avatarStyle: momAvatar, expression: MomExpression.notes, eyebrow: 'The rundown', message: momMessage),
          const SizedBox(height: AppSpacing.momSectionGap),
          _FinanceCard(
            spentCents: spentCents,
            budgetCents: budgetCents,
            currency: currency,
            biggestCategory: biggestCategory,
            onTap: () => context.push('/track/finance'),
          ),
          const SizedBox(height: AppSpacing.momRowGap),
          _HealthCard(goals: goals, today: today, onTap: () => context.push('/track/health')),
        ],
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  const _FinanceCard({
    required this.spentCents,
    required this.budgetCents,
    required this.currency,
    required this.biggestCategory,
    required this.onTap,
  });

  final int spentCents;
  final int? budgetCents;
  final String currency;
  final String? biggestCategory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final ratio = budgetCents != null && budgetCents! > 0 ? spentCents / budgetCents! : null;
    final over = budgetCents != null && spentCents > budgetCents!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanelSm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanelSm), boxShadow: MomElevation.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: mom.tints[1], borderRadius: BorderRadius.circular(AppSpacing.momRadiusTile)),
                  child: Icon(LucideIcons.wallet, size: 20, color: mom.tintIcons[1]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Financial', style: MomText.cardTitle(mom.ink)),
                      Text(
                        budgetCents != null
                            ? '${formatMoney(spentCents, currency)} of ${formatMoney(budgetCents!, currency)} spent'
                            : '${formatMoney(spentCents, currency)} spent so far',
                        style: MomText.meta(mom.inkMuted),
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 18, color: mom.inkMuted),
              ],
            ),
            if (ratio != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: mom.fieldBorder,
                  valueColor: AlwaysStoppedAnimation(mom.doneOrange),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                over
                    ? '${formatMoney(spentCents - budgetCents!, currency)} over${biggestCategory != null ? ' · $biggestCategory is your biggest line' : ''}'
                    : biggestCategory != null
                        ? '$biggestCategory is your biggest line'
                        : 'On track this month',
                style: MomText.meta(mom.inkMuted, size: 11.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.goals, required this.today, required this.onTap});
  final HealthGoals? goals;
  final HealthToday? today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final waterCount = today?.waterCount ?? 0;
    final workoutMinutes = today?.workoutMinutes ?? 0;
    final sleepHours = today?.sleepHours;
    final hasAnyLog = goals != null && (waterCount > 0 || sleepHours != null || workoutMinutes > 0);
    final goalsSnapshot = goals;
    final segments = goalsSnapshot == null
        ? null
        : [
            (waterCount / goalsSnapshot.waterTarget).clamp(0.0, 1.0),
            sleepHours == null ? 0.0 : (sleepHours / goalsSnapshot.sleepTargetHours).clamp(0.0, 1.0),
            (workoutMinutes / goalsSnapshot.workoutTargetMinutes).clamp(0.0, 1.0),
          ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanelSm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanelSm), boxShadow: MomElevation.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: mom.tints[3], borderRadius: BorderRadius.circular(AppSpacing.momRadiusTile)),
                  child: Icon(LucideIcons.heartPulse, size: 20, color: mom.tintIcons[3]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Health', style: MomText.cardTitle(mom.ink)),
                      Text(
                        goals == null ? 'Set your goals to start tracking' : '$waterCount/${goals.waterTarget} water · ${workoutMinutes}/${goals.workoutTargetMinutes}m active',
                        style: MomText.meta(mom.inkMuted),
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 18, color: mom.inkMuted),
              ],
            ),
            if (segments != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < segments.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
                        child: LinearProgressIndicator(
                          value: segments[i],
                          minHeight: 6,
                          backgroundColor: mom.hairline,
                          valueColor: AlwaysStoppedAnimation(mom.doneOrange),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(hasAnyLog ? 'Logged today' : 'Nothing logged today', style: MomText.meta(mom.inkMuted, size: 11.5)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackLocked extends ConsumerWidget {
  const _TrackLocked();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    final momAvatar = ref.watch(effectiveMomAvatarProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, AppSpacing.lg, AppSpacing.momGutter, 96),
        children: [
          Text('Track', style: MomText.screenTitle(mom.ink)),
          const SizedBox(height: 2),
          Text('${DateFormat('MMMM').format(DateTime.now())} · money and body', style: MomText.body(mom.inkSoft)),
          const SizedBox(height: AppSpacing.momSectionGap),
          Opacity(opacity: 0.55, child: _LockedRow(icon: LucideIcons.wallet, title: 'Financial', value: 'Track your spending')),
          const SizedBox(height: AppSpacing.momRowGap),
          Opacity(opacity: 0.55, child: _LockedRow(icon: LucideIcons.heartPulse, title: 'Health', value: 'Track water, sleep, movement')),
          const SizedBox(height: AppSpacing.momSectionGap),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: mom.promoPeach, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanel)),
            child: Column(
              children: [
                MomAvatar(style: momAvatar, expression: MomExpression.happy, showMoodBadge: false, size: 52),
                const SizedBox(height: 12),
                Text('LOCKED FOR NOW', style: MomText.eyebrow(mom.tintIcons[0])),
                const SizedBox(height: 4),
                Text(
                  "Full Mom keeps an eye on both money and body — Basic Mom is tasks only, for now.",
                  textAlign: TextAlign.center,
                  style: MomText.momMessage(mom.ink),
                ),
                const SizedBox(height: 16),
                MomSecondaryButton(
                  label: 'Unlock with Full Mom',
                  icon: LucideIcons.lock,
                  isMainCta: true,
                  onPressed: () => context.push('/upgrade'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.momSectionGap),
          Text("What you'd get", style: MomText.section(mom.ink)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _WhatYoudGetCard(tintIndex: 0, title: 'Money', body: 'Budgets, expense logging, and spend-by-category tracking.')),
              const SizedBox(width: AppSpacing.momRowGap),
              Expanded(child: _WhatYoudGetCard(tintIndex: 4, title: 'Body', body: 'Water, sleep, and movement goals with daily check-ins.')),
            ],
          ),
        ],
      ),
    );
  }
}

class _LockedRow extends StatelessWidget {
  const _LockedRow({required this.icon, required this.title, required this.value});
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanelSm), boxShadow: MomElevation.card),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: mom.neutralTile, borderRadius: BorderRadius.circular(AppSpacing.momRadiusTile)),
            child: Icon(icon, size: 20, color: mom.inkMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: MomText.cardTitle(mom.ink)),
                Text(value, style: MomText.meta(mom.inkMuted)),
              ],
            ),
          ),
          Icon(LucideIcons.lock, size: 16, color: mom.inkMuted),
        ],
      ),
    );
  }
}

class _WhatYoudGetCard extends StatelessWidget {
  const _WhatYoudGetCard({required this.tintIndex, required this.title, required this.body});
  final int tintIndex;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final tint = mom.tints[tintIndex % mom.tints.length];
    final tintIcon = mom.tintIcons[tintIndex % mom.tintIcons.length];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: MomText.cardTitle(tintIcon)),
          const SizedBox(height: 4),
          Text(body, style: MomText.meta(mom.inkSoft)),
        ],
      ),
    );
  }
}
