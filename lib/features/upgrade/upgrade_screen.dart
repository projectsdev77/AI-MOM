import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/plan.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/purchases_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';

/// Reached by tapping a Full-only preview on the Dashboard, or "Upgrade"
/// wherever else it appears. Real purchases need RevenueCat wired up on
/// an actual iOS/Android build (see README) — that's tracked separately
/// in TODO.md, so this screen explains the plan and falls back to the
/// Settings debug toggle for testing in the meantime.
class UpgradeScreen extends ConsumerWidget {
  const UpgradeScreen({super.key});

  static const _benefits = [
    'Unlimited tasks and habits',
    'Unlimited chats with Mom',
    'Financial tracking and budgets',
    'Health tracking and goals',
    'More check-ins throughout the day',
  ];

  Future<void> _restore(BuildContext context) async {
    try {
      await PurchasesService.restorePurchases();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases restored.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't restore purchases right now.")),
        );
      }
    }
  }

  void _seePlans(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Subscriptions open once this is running on iOS/Android with RevenueCat connected. '
          'For now, flip "Debug: preview plan" in Settings to try Full Mom.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plan = ref.watch(planProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Full Mom Experience')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (plan.isFull)
            Text("You're already on Full Mom Experience.", style: theme.textTheme.bodyLarge)
          else ...[
            Text('Everything Mom can do, all the time.', style: theme.textTheme.headlineLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Basic Mom covers the essentials. Full Mom Experience unlocks:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final b in _benefits)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(LucideIcons.circleCheck, size: 18, color: AppColors.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(b, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: 'See plans', onPressed: () => _seePlans(context)),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: () => _restore(context),
                child: const Text('Restore purchases'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
