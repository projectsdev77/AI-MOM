import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/app_state_provider.dart';
import '../../core/providers/currency_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/track_providers.dart';
import '../../core/repositories/finance_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_mood.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/mom_components.dart';
import '../shell/app_shell.dart';
import 'finance_widgets.dart';

class FinanceDetailScreen extends ConsumerWidget {
  const FinanceDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    final momAvatar = ref.watch(effectiveMomAvatarProvider);
    final expensesAsync = ref.watch(expensesThisMonthProvider);
    final overallBudgetAsync = ref.watch(overallBudgetCentsProvider);
    final categoryBudgetsAsync = ref.watch(categoryBudgetsProvider);
    final currency = ref.watch(currencyProvider);

    final expenses = expensesAsync.valueOrNull ?? const [];
    final spentByCategory = <String, int>{};
    for (final e in expenses) {
      spentByCategory[e.category] = (spentByCategory[e.category] ?? 0) + e.amountCents;
    }
    final categoryBudgets = categoryBudgetsAsync.valueOrNull ?? const {};
    final categories = {...spentByCategory.keys, ...categoryBudgets.keys}.toList()
      ..sort((a, b) => (spentByCategory[b] ?? 0).compareTo(spentByCategory[a] ?? 0));

    final totalSpent = expenses.fold<int>(0, (sum, e) => sum + e.amountCents);
    final overallBudget = overallBudgetAsync.valueOrNull;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dailyAverageCents = now.day > 0 ? (totalSpent / now.day).round() : 0;
    final daysLeft = daysInMonth - now.day;
    final biggestCategory = categories.isEmpty ? null : categories.first;

    return Scaffold(
      backgroundColor: mom.shell,
      appBar: AppBar(
        backgroundColor: mom.shell,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, size: 22, color: mom.espresso),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Financial tracking', style: MomText.cardTitle(mom.ink)),
        actions: [
          _CurrencyBadge(current: currency, onChanged: (code) {
            ref.read(currencyProvider.notifier).state = code;
            saveCurrency(code);
          }),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      floatingActionButton: MomFab(tooltip: 'Log an expense', onPressed: () => showAddExpenseSheet(context)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, AppSpacing.sm, AppSpacing.momGutter, 96),
        children: [
          _SummaryPanel(
            spentCents: totalSpent,
            budgetCents: overallBudget,
            currency: currency,
            onEditBudget: () => showSetBudgetDialog(context, ref, currentCents: overallBudget),
          ),
          const SizedBox(height: AppSpacing.momSectionGap),
          Row(
            children: [
              Expanded(child: MomStatCard(icon: LucideIcons.trendingUp, tintIndex: 1, value: formatMoney(dailyAverageCents, currency), caption: 'Daily average')),
              const SizedBox(width: AppSpacing.momRowGap),
              Expanded(child: MomStatCard(icon: LucideIcons.receipt, tintIndex: 2, value: '${expenses.length}', caption: 'Expenses logged')),
              const SizedBox(width: AppSpacing.momRowGap),
              Expanded(child: MomStatCard(icon: LucideIcons.calendarDays, tintIndex: 4, value: '$daysLeft', caption: 'Days left')),
            ],
          ),
          const SizedBox(height: AppSpacing.momSectionGap),
          Text('By category', style: MomText.section(mom.ink)),
          const SizedBox(height: AppSpacing.sm),
          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: Text('No spending logged yet this month.', style: MomText.body(mom.inkMuted))),
            )
          else
            for (var i = 0; i < categories.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.momRowGap),
                child: _CategoryCard(
                  category: categories[i],
                  tintIndex: i,
                  spentCents: spentByCategory[categories[i]] ?? 0,
                  totalSpentCents: totalSpent,
                  budgetCents: categoryBudgets[categories[i]],
                  currency: currency,
                  expenses: expenses.where((e) => e.category == categories[i]).toList(),
                ),
              ),
          const SizedBox(height: AppSpacing.momSectionGap),
          MomMessageCard(
            avatarStyle: momAvatar,
            expression: MomExpression.mad,
            eyebrow: 'Money talk',
            message: biggestCategory != null
                ? '$biggestCategory is where most of it went this month. Worth a look?'
                : "Log your first expense and I'll start keeping tabs.",
          ),
        ],
      ),
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge({required this.current, required this.onChanged});
  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return PopupMenuButton<String>(
      initialValue: current,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final code in currencySymbols.keys)
          PopupMenuItem(value: code, child: Text('$code (${currencySymbols[code]})')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current, style: MomText.control(mom.ink, size: 12.5)),
            Icon(LucideIcons.chevronDown, size: 14, color: mom.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.spentCents, required this.budgetCents, required this.currency, required this.onEditBudget});

  final int spentCents;
  final int? budgetCents;
  final String currency;
  final VoidCallback onEditBudget;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final ratio = budgetCents != null && budgetCents! > 0 ? (spentCents / budgetCents!).clamp(0.0, 1.0) : 0.0;
    final remaining = budgetCents != null ? budgetCents! - spentCents : null;
    final over = remaining != null && remaining < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: mom.promoPeach, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanel)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('This month', style: MomText.meta(mom.peachPanelMuted)),
              GestureDetector(
                onTap: onEditBudget,
                child: Text(budgetCents == null ? 'Set budget' : 'Edit budget', style: MomText.control(mom.espresso)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: remaining != null
                      ? (over ? formatMoney(-remaining, currency) : formatMoney(remaining, currency))
                      : formatMoney(spentCents, currency),
                  style: MomText.bigValue(mom.ink),
                ),
                if (remaining != null)
                  TextSpan(text: over ? ' over budget' : ' left', style: MomText.rowLabel(mom.peachPanelMuted)),
              ],
            ),
          ),
          if (budgetCents != null) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: mom.peachOnPeach,
                valueColor: AlwaysStoppedAnimation(mom.doneOrange),
              ),
            ),
            const SizedBox(height: 8),
            Text('${formatMoney(spentCents, currency)} spent · ${formatMoney(budgetCents!, currency)} budget', style: MomText.meta(mom.peachPanelMuted)),
          ],
        ],
      ),
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({
    required this.category,
    required this.tintIndex,
    required this.spentCents,
    required this.totalSpentCents,
    required this.budgetCents,
    required this.currency,
    required this.expenses,
  });

  final String category;
  final int tintIndex;
  final int spentCents;
  final int totalSpentCents;
  final int? budgetCents;
  final String currency;
  final List<ExpenseRow> expenses;

  Future<void> _confirmAndClearBudget(BuildContext context, WidgetRef ref) async {
    final mom = context.mom;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove budget for $category?'),
        content: const Text("You'll still see what's spent, just without the tracker."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: TextStyle(color: mom.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      if (context.mounted) Slidable.of(context)?.close();
      return;
    }
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    try {
      await ref.read(financeRepositoryProvider).deleteCategoryBudget(userId: userId, category: category);
      ref.invalidate(categoryBudgetsProvider);
    } catch (e) {
      if (context.mounted) {
        Slidable.of(context)?.close();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  void _showExpenses(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryExpensesSheet(category: category, currency: currency, expenses: expenses),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    final tint = mom.tints[tintIndex % mom.tints.length];
    final tintIcon = mom.tintIcons[tintIndex % mom.tintIcons.length];
    final share = totalSpentCents > 0 ? (spentCents / totalSpentCents).clamp(0.0, 1.0) : 0.0;
    final shareWidth = share < 0.04 ? 0.04 : share;

    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard)),
      child: InkWell(
        onTap: () => _showExpenses(context),
        borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppSpacing.momRadiusTile - 1)),
                  child: Icon(LucideIcons.tag, size: 16, color: tintIcon),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(category, style: MomText.rowLabel(mom.ink), overflow: TextOverflow.ellipsis)),
                Text(
                  budgetCents != null ? '${formatMoney(spentCents, currency)}/${formatMoney(budgetCents!, currency)}' : formatMoney(spentCents, currency),
                  style: MomText.cardTitle(mom.ink),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: shareWidth,
                child: Container(height: 5, color: tintIcon),
              ),
            ),
          ],
        ),
      ),
    );

    if (budgetCents == null) return card;

    return Slidable(
      key: ValueKey(category),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (actionContext) => _confirmAndClearBudget(actionContext, ref),
            backgroundColor: mom.danger,
            foregroundColor: Colors.white,
            icon: LucideIcons.trash2,
            borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
          ),
        ],
      ),
      child: card,
    );
  }
}

class _CategoryExpensesSheet extends ConsumerWidget {
  const _CategoryExpensesSheet({required this.category, required this.currency, required this.expenses});
  final String category;
  final String currency;
  final List<ExpenseRow> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, AppSpacing.lg, AppSpacing.momGutter, AppSpacing.xl),
      decoration: BoxDecoration(
        color: mom.shell,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.momRadiusSheet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category, style: MomText.cardTitle(mom.ink)),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  showSetCategoryBudgetDialog(context, ref, category: category);
                },
                child: Text('Set budget', style: MomText.control(mom.espresso)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final e in expenses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${e.spentAt.month}/${e.spentAt.day}${e.note != null && e.note!.isNotEmpty ? ' — ${e.note}' : ''}',
                          style: MomText.body(mom.inkSoft),
                        ),
                        Text(formatMoney(e.amountCents, currency), style: MomText.rowLabel(mom.ink)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
