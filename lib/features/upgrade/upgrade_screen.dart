import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/models/plan.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/purchases_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_mood.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/mom_avatar.dart';
import '../../core/widgets/mom_components.dart';
import '../../core/widgets/primary_button.dart';

const _perks = [
  (title: 'Unlimited tasks and habits', sub: 'No caps on your list — track everything you want to.'),
  (title: 'Unlimited chats with Mom', sub: 'Talk as much as you need, any day of the week.'),
  (title: 'Financial tracking and budgets', sub: 'Log expenses and set budgets by category.'),
  (title: 'Health tracking and goals', sub: 'Water, sleep, and movement — all in one place.'),
  (title: 'More check-ins throughout the day', sub: 'Mom keeps closer tabs when you want her to.'),
];

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
    final mom = context.mom;
    final plan = ref.watch(planProvider);

    return Scaffold(
      backgroundColor: mom.shell,
      appBar: AppBar(
        backgroundColor: mom.shell,
        elevation: 0,
        title: Text(_showingPlans ? 'Choose a plan' : 'Full Mom Experience', style: MomText.cardTitle(mom.ink)),
        leading: _showingPlans
            ? IconButton(
                icon: Icon(LucideIcons.chevronLeft, size: 22, color: mom.espresso),
                onPressed: () => setState(() => _showingPlans = false),
              )
            : (Navigator.of(context).canPop()
                ? IconButton(
                    icon: Icon(LucideIcons.chevronLeft, size: 22, color: mom.espresso),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null),
      ),
      body: plan.isFull
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.momGutter),
              child: Text("You're already on Full Mom Experience.", style: MomText.body(mom.ink)),
            )
          : _showingPlans
              ? _PlansView(loading: _loadingOffering, purchasing: _purchasing, offering: _offering, error: _error, onBuy: _buy)
              : _BenefitsView(onSeePlans: _seePlans, onRestore: _restore),
    );
  }
}

class _BenefitsView extends ConsumerWidget {
  const _BenefitsView({required this.onSeePlans, required this.onRestore});
  final VoidCallback onSeePlans;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    final momAvatar = ref.watch(effectiveMomAvatarProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, AppSpacing.sm, AppSpacing.momGutter, AppSpacing.xxl),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.momGutter),
          decoration: BoxDecoration(color: mom.promoPeach, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanel)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MomAvatar(style: momAvatar, expression: MomExpression.happy, showMoodBadge: false, size: 60),
              const SizedBox(height: 12),
              Text('Everything Mom can do, all the time.', style: MomText.screenTitle(mom.ink)),
              const SizedBox(height: 6),
              Text('Basic Mom covers the essentials. Full Mom Experience unlocks:', style: MomText.body(mom.peachPanelMuted)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.momSectionGap),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanelSm), boxShadow: MomElevation.card),
          child: Column(
            children: [
              for (final p in _perks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: mom.doneOrange, width: 2)),
                        child: Icon(LucideIcons.check, size: 12, color: mom.doneOrange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.title, style: MomText.taskTitle(mom.ink)),
                            Text(p.sub, style: MomText.rowSub(mom.inkMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.momSectionGap),
        PrimaryButton(label: 'See plans', onPressed: onSeePlans),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: GestureDetector(
            onTap: onRestore,
            child: Text('Restore purchases', style: MomText.control(mom.inkMuted)),
          ),
        ),
      ],
    );
  }
}

class _PlansView extends ConsumerStatefulWidget {
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
  ConsumerState<_PlansView> createState() => _PlansViewState();
}

class _PlansViewState extends ConsumerState<_PlansView> {
  Package? _selected;
  // Selection for the non-purchasable preview cards (no RevenueCat
  // products configured yet) - purely visual, Continue stays disabled
  // either way since there's nothing real to buy.
  String? _selectedMockPlan;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final momAvatar = ref.watch(effectiveMomAvatarProvider);

    if (widget.loading) {
      return Center(child: CircularProgressIndicator(color: mom.espresso));
    }

    final packages = widget.offering?.availablePackages ?? const [];
    final isMock = packages.isEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, AppSpacing.sm, AppSpacing.momGutter, AppSpacing.lg),
            children: [
              Text('Choose your plan', style: MomText.screenTitle(mom.ink)),
              const SizedBox(height: 6),
              Text(
                isMock
                    ? "Pricing goes live once this app is connected to the App Store and Play Store — here's a preview of how it'll look."
                    : 'Pick the plan that works for you.',
                style: MomText.body(mom.inkSoft),
              ),
              const SizedBox(height: AppSpacing.momSectionGap),
              if (isMock) ...[
                _PlanCard(
                  title: 'Monthly',
                  sub: 'Cancel anytime.',
                  priceLabel: 'Price shown at launch',
                  bestValue: false,
                  selected: _selectedMockPlan == 'monthly',
                  onTap: () => setState(() => _selectedMockPlan = 'monthly'),
                ),
                const SizedBox(height: AppSpacing.momRowGap),
                _PlanCard(
                  title: 'Yearly',
                  sub: 'Best value — one payment a year.',
                  priceLabel: 'Price shown at launch',
                  bestValue: true,
                  selected: _selectedMockPlan == 'yearly',
                  onTap: () => setState(() => _selectedMockPlan = 'yearly'),
                ),
              ] else
                for (final package in packages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.momRowGap),
                    child: _PlanCard(
                      title: package.storeProduct.title,
                      sub: package.storeProduct.description,
                      priceLabel: package.storeProduct.priceString,
                      bestValue: package.packageType == PackageType.annual,
                      selected: _selected?.identifier == package.identifier,
                      onTap: () => setState(() => _selected = package),
                    ),
                  ),
              const SizedBox(height: AppSpacing.momSectionGap),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanelSm), boxShadow: MomElevation.card),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Both plans include', style: MomText.section(mom.ink)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final label in const ['Unlimited tasks', 'Unlimited chats', 'Financial tracking', 'Health tracking', 'More check-ins'])
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: mom.shell, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill)),
                            child: Text(label, style: MomText.meta(mom.inkSoft, size: 12)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isMock) ...[
                const SizedBox(height: AppSpacing.momSectionGap),
                MomMessageCard(
                  avatarStyle: momAvatar,
                  expression: MomExpression.notes,
                  eyebrow: 'Behind the scenes',
                  message: 'For now, use the "Debug: preview plan" switch in Settings to try out what Full Mom looks like.',
                ),
              ],
              if (widget.error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(widget.error!, style: MomText.meta(mom.danger)),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, 0, AppSpacing.momGutter, AppSpacing.md),
            child: PrimaryButton(
              label: widget.purchasing ? 'Purchasing…' : 'Continue',
              onPressed: (!isMock && _selected != null && !widget.purchasing) ? () => widget.onBuy(_selected!) : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.sub,
    required this.priceLabel,
    required this.bestValue,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String sub;
  final String priceLabel;
  final bool bestValue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? mom.promoPeach : mom.surface,
          borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanelSm),
          border: selected ? Border.all(color: mom.espresso, width: 1.5) : Border.all(color: mom.checkIdleBorder, width: 2),
          boxShadow: selected ? null : MomElevation.card,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(title, style: MomText.cardTitle(mom.ink).copyWith(fontWeight: selected ? FontWeight.w800 : FontWeight.w700)),
                      if (bestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : mom.tints[0],
                            borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
                          ),
                          child: Text('BEST VALUE', style: MomText.taskMetaLabel(mom.tintIcons[0])),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(sub, style: MomText.rowSub(mom.inkMuted)),
                  const SizedBox(height: 4),
                  Text(priceLabel, style: MomText.control(mom.inkSoft)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? mom.espresso : Colors.transparent,
                border: Border.all(color: selected ? mom.espresso : mom.checkIdleBorder, width: 2),
              ),
              child: selected ? const Icon(LucideIcons.check, size: 13, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}
