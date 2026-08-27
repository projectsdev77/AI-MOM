import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/models/plan.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/purchases_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/primary_button.dart';

/// Reached by tapping a Full-only preview on the Dashboard, or "Upgrade"
/// wherever else it appears. "See plans" shows the real RevenueCat
/// offering when one is configured; before that's set up (no App
/// Store/Play Store products yet — see README), it shows an honest
/// "not open yet" state instead of pretending a purchase would work.
class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  static const _benefits = [
    'Unlimited tasks and habits',
    'Unlimited chats with Mom',
    'Financial tracking and budgets',
    'Health tracking and goals',
    'More check-ins throughout the day',
  ];

  bool _showingPlans = false;
  bool _loadingOffering = false;
  bool _purchasing = false;
  Offering? _offering;
  String? _error;

  Future<void> _seePlans() async {
    setState(() {
      _showingPlans = true;
      _loadingOffering = true;
      _error = null;
    });
    final offering = await PurchasesService.fetchCurrentOffering();
    if (mounted) {
      setState(() {
        _offering = offering;
        _loadingOffering = false;
      });
    }
  }

  Future<void> _buy(Package package) async {
    setState(() {
      _purchasing = true;
      _error = null;
    });
    try {
      await PurchasesService.purchasePackage(package);
      // customerInfoProvider's listener picks up the new entitlement on
      // its own — planProvider will flip to Full without anything more
      // to do here.
      if (mounted) Navigator.of(context).maybePop();
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError && mounted) {
        setState(() => _error = friendlyError(e));
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    try {
      await PurchasesService.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases restored.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = ref.watch(planProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_showingPlans ? 'Choose a plan' : 'Full Mom Experience'),
        leading: _showingPlans
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => setState(() => _showingPlans = false),
              )
            : null,
      ),
      body: plan.isFull
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text("You're already on Full Mom Experience.", style: theme.textTheme.bodyLarge),
            )
          : _showingPlans
              ? _PlansView(
                  loading: _loadingOffering,
                  purchasing: _purchasing,
                  offering: _offering,
                  error: _error,
                  onBuy: _buy,
                )
              : _BenefitsView(onSeePlans: _seePlans, onRestore: _restore),
    );
  }
}

class _BenefitsView extends StatelessWidget {
  const _BenefitsView({required this.onSeePlans, required this.onRestore});
  final VoidCallback onSeePlans;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Everything Mom can do, all the time.', style: theme.textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Basic Mom covers the essentials. Full Mom Experience unlocks:',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final b in _UpgradeScreenState._benefits)
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
        PrimaryButton(label: 'See plans', onPressed: onSeePlans),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(onPressed: onRestore, child: const Text('Restore purchases')),
        ),
      ],
    );
  }
}

class _PlansView extends StatelessWidget {
  const _PlansView({
    required this.loading,
    required this.purchasing,
    required this.offering,
    required this.error,
    required this.onBuy,
  });

  final bool loading;
  final bool purchasing;
  final Offering? offering;
  final String? error;
  final ValueChanged<Package> onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    final packages = offering?.availablePackages ?? const [];
    if (packages.isEmpty) {
      // No RevenueCat project configured yet, or one with no products
      // in it — real state, not an error. Shown as a preview of the
      // real pricing screen (disabled, no invented numbers) rather than
      // a bare paragraph, so it reads as finished, not missing.
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Choose your plan', style: theme.textTheme.headlineLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Pricing goes live once this app is connected to the App Store and Play Store — "
            'here\'s a preview of how it\'ll look.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _MockPlanCard(label: 'Monthly', description: 'Cancel anytime.'),
          const SizedBox(height: AppSpacing.md),
          const _MockPlanCard(label: 'Yearly', description: 'Best value — one payment a year.'),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              'For now, use the "Debug: preview plan" switch in Settings to try out what Full Mom looks like.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final package in packages)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _PlanCard(package: package, disabled: purchasing, onTap: () => onBuy(package)),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(error!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.moodDisappointed)),
          ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.package, required this.disabled, required this.onTap});
  final Package package;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = package.storeProduct;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.accent, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title, style: theme.textTheme.titleMedium),
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(product.description, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(product.priceString, style: theme.textTheme.titleMedium?.copyWith(color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}

/// A preview of what a real plan card will look like once RevenueCat
/// has actual products configured — deliberately not tappable, and
/// never shows an invented price (that's set at App Store/Play Store
/// setup time, not decided here).
class _MockPlanCard extends StatelessWidget {
  const _MockPlanCard({required this.label, required this.description});
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: 0.55,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(description, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(LucideIcons.lock, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
