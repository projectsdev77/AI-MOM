import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/plan.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/locked_feature_overlay.dart';
import '../../core/widgets/section_header.dart';

class TrackScreen extends ConsumerWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    final theme = Theme.of(context);

    Widget financeCard = _FinanceCard();
    Widget healthCard = _HealthCard();
    if (!plan.isFull) {
      financeCard = LockedFeatureOverlay(featureName: 'Financial tracking', child: financeCard);
      healthCard = LockedFeatureOverlay(featureName: 'Health tracking', child: healthCard);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Track')),
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
                'Financial and health tracking are part of Full Mom Experience.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SectionHeader(title: 'Spending'),
          const SizedBox(height: AppSpacing.sm),
          financeCard,
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Health'),
          const SizedBox(height: AppSpacing.sm),
          healthCard,
        ],
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  const _FinanceCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const spent = 340.0;
    const budget = 500.0;
    final ratio = (spent / budget).clamp(0.0, 1.0);
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('This month', style: theme.textTheme.bodySmall),
              const Icon(LucideIcons.wallet, size: 18, color: AppColors.accent),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('\$${spent.toStringAsFixed(0)} of \$${budget.toStringAsFixed(0)} budget',
              style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppColors.chipPeach,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Eating out is your biggest category this week.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(child: _HealthMetric(icon: LucideIcons.droplets, label: 'Water', value: '5/8')),
          Expanded(child: _HealthMetric(icon: LucideIcons.moon, label: 'Sleep', value: '6.5h')),
          Expanded(child: _HealthMetric(icon: LucideIcons.dumbbell, label: 'Movement', value: '20m')),
        ],
      ),
    );
  }
}

class _HealthMetric extends StatelessWidget {
  const _HealthMetric({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: 22),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: theme.textTheme.titleMedium),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
