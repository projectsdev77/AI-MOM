import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/service_providers.dart';
import '../../core/providers/track_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/primary_button.dart';

const kExpenseCategories = ['Food & drink', 'Groceries', 'Transport', 'Shopping', 'Bills', 'Entertainment', 'Other'];

Future<void> showAddExpenseSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AddExpenseSheet(),
  );
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  const _AddExpenseSheet();

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _amountController = TextEditingController();
  final _customCategoryController = TextEditingController();
  String _category = kExpenseCategories.first;
  bool _customSelected = false;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  bool get _canSave {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return false;
    if (_customSelected && _customCategoryController.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null) return;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).addExpense(
            userId: userId,
            amountCents: (amount * 100).round(),
            category: _customSelected ? _customCategoryController.text.trim() : _category,
          );
      ref.invalidate(expensesThisMonthProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fieldDecoration = InputDecoration(
      filled: true,
      fillColor: theme.cardTheme.color,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
        borderSide: BorderSide(color: theme.dividerTheme.color ?? AppColors.borderLight),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Log an expense', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _amountController,
              onChanged: (_) => setState(() {}),
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: fieldDecoration.copyWith(hintText: 'Amount (e.g. 12.50)'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Category', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final c in kExpenseCategories)
                  AppPillChip(
                    label: c,
                    selected: !_customSelected && _category == c,
                    onTap: () => setState(() {
                      _customSelected = false;
                      _category = c;
                    }),
                  ),
                AppPillChip(
                  label: 'Custom',
                  selected: _customSelected,
                  onTap: () => setState(() => _customSelected = true),
                ),
              ],
            ),
            if (_customSelected) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _customCategoryController,
                onChanged: (_) => setState(() {}),
                decoration: fieldDecoration.copyWith(hintText: 'Category name'),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: _saving ? 'Saving...' : 'Add expense',
              onPressed: (_canSave && !_saving) ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showSetBudgetDialog(BuildContext context, WidgetRef ref, {int? currentCents}) {
  final controller = TextEditingController(
    text: currentCents != null ? (currentCents / 100).toStringAsFixed(0) : '',
  );
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Monthly budget'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: 'e.g. 500'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            final amount = double.tryParse(controller.text);
            if (amount == null || amount <= 0) return;
            final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
            if (userId == null) return;
            await ref.read(financeRepositoryProvider).setOverallBudget(
                  userId: userId,
                  amountCents: (amount * 100).round(),
                );
            ref.invalidate(overallBudgetCentsProvider);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
