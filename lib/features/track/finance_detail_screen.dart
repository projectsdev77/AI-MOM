import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/currency_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/track_providers.dart';
import '../../core/repositories/finance_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/friendly_error.dart';
import 'finance_widgets.dart';

class FinanceDetailScreen extends ConsumerWidget {
  const FinanceDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial tracking'),
        actions: [
          _CurrencyBadge(current: currency, onChanged: (code) {
            ref.read(currencyProvider.notifier).state = code;
            saveCurrency(code);
          }),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        onPressed: () => showAddExpenseSheet(context),
        child: const Icon(LucideIcons.plus),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
        children: [
          _TotalBudgetCard(
            spentCents: totalSpent,
            budgetCents: overallBudget,
            currency: currency,
            onSetBudget: () => showSetBudgetDialog(context, ref, currentCents: overallBudget),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('By category', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text('No spending logged yet this month.', style: theme.textTheme.bodySmall),
              ),
            )
          else
            for (final category in categories)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _CategoryCard(
                  category: category,
                  spentCents: spentByCategory[category] ?? 0,
                  budgetCents: categoryBudgets[category],
                  currency: currency,
                  expenses: expenses.where((e) => e.category == category).toList(),
                ),
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
    return PopupMenuButton<String>(
      initialValue: current,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final code in currencySymbols.keys)
          PopupMenuItem(value: code, child: Text('$code (${currencySymbols[code]})')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(current, style: Theme.of(context).textTheme.bodySmall),
            const Icon(LucideIcons.chevronDown, size: 14),
          ],
        ),
      ),
    );
  }
}

class _TotalBudgetCard extends StatelessWidget {
  const _TotalBudgetCard({
    required this.spentCents,
    required this.budgetCents,
    required this.currency,
    required this.onSetBudget,
  });

  final int spentCents;
  final int? budgetCents;
  final String currency;
  final VoidCallback onSetBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = budgetCents != null && budgetCents! > 0 ? (spentCents / budgetCents!).clamp(0.0, 1.0) : 0.0;
    final remaining = budgetCents != null ? budgetCents! - spentCents : null;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('This month', style: theme.textTheme.bodySmall),
              TextButton(onPressed: onSetBudget, child: Text(budgetCents == null ? 'Set budget' : 'Edit budget')),
            ],
          ),
          Text(
            remaining != null
                ? (remaining < 0
                    ? '${formatMoney(-remaining, currency)} over budget'
                    : '${formatMoney(remaining, currency)} left')
                : '${formatMoney(spentCents, currency)} spent',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: remaining != null && remaining < 0 ? AppColors.moodDisappointed : null,
            ),
          ),
          if (budgetCents != null) ...[
            const SizedBox(height: 2),
            Text(
              '${formatMoney(spentCents, currency)} of ${formatMoney(budgetCents!, currency)} budget',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: AppColors.chipPeach,
                valueColor: AlwaysStoppedAnimation(ratio >= 1 ? AppColors.moodDisappointed : AppColors.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({
    required this.category,
    required this.spentCents,
    required this.budgetCents,
    required this.currency,
    required this.expenses,
  });

  final String category;
  final int spentCents;
  final int? budgetCents;
  final String currency;
  final List<ExpenseRow> expenses;

  Future<void> _confirmAndClearBudget(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove budget for $category?'),
        content: const Text("You'll still see what's spent, just without the tracker."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.moodDisappointed)),
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
    final theme = Theme.of(context);
    final ratio = budgetCents != null && budgetCents! > 0 ? (spentCents / budgetCents!).clamp(0.0, 1.0) : null;
    final fillColor = ratio == null
        ? null
        : (ratio >= 1 ? AppColors.moodDisappointed : AppColors.accent).withValues(alpha: 0.16);

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
      child: InkWell(
        onTap: () => _showExpenses(context),
        child: Stack(
          children: [
            Container(color: theme.cardTheme.color),
            if (ratio != null)
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(height: double.infinity, color: fillColor),
              ),
            Container(
              decoration: BoxDecoration(border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight)),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(category, style: theme.textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    budgetCents != null
                        ? '${formatMoney(spentCents, currency)}/${formatMoney(budgetCents!, currency)}'
                        : formatMoney(spentCents, currency),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (budgetCents == null) return SizedBox(height: 56, child: card);

    return SizedBox(
      height: 56,
      child: Slidable(
        key: ValueKey(category),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.22,
          children: [
            SlidableAction(
              onPressed: (actionContext) => _confirmAndClearBudget(actionContext, ref),
              backgroundColor: AppColors.moodDisappointed,
              foregroundColor: Colors.white,
              icon: LucideIcons.trash2,
              borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
            ),
          ],
        ),
        child: card,
      ),
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
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSheet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category, style: theme.textTheme.titleLarge),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  showSetCategoryBudgetDialog(context, ref, category: category);
                },
                child: const Text('Set budget'),
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
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(formatMoney(e.amountCents, currency), style: theme.textTheme.bodyMedium),
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
