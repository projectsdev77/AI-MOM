import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_state_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/track_providers.dart';
import '../../core/repositories/finance_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_mood.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/mom_avatar.dart';
import '../../core/widgets/mom_components.dart';
import '../../core/widgets/primary_button.dart';

const kExpenseCategories = ['Food & drink', 'Groceries', 'Transport', 'Shopping', 'Bills', 'Entertainment', 'Other'];

Future<void> showAddExpenseSheet(BuildContext context, {ExpenseRow? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: context.mom.ink.withValues(alpha: 0.28),
    builder: (context) => _AddExpenseSheet(existing: existing),
  );
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  const _AddExpenseSheet({this.existing});
  final ExpenseRow? existing;

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  late final _amountController = TextEditingController(
    text: widget.existing != null ? (widget.existing!.amountCents / 100).toStringAsFixed(2) : '',
  );
  late final _customCategoryController = TextEditingController(
    text: _startsCustom ? widget.existing!.category : '',
  );
  late String _category = _startsCustom ? kExpenseCategories.first : (widget.existing?.category ?? kExpenseCategories.first);
  late bool _customSelected = _startsCustom;
  bool _saving = false;

  bool get _startsCustom => widget.existing != null && !kExpenseCategories.contains(widget.existing!.category);
  bool get _isEditing => widget.existing != null;

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
    final category = _customSelected ? _customCategoryController.text.trim() : _category;

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await ref.read(financeRepositoryProvider).updateExpense(
              expenseId: widget.existing!.id,
              amountCents: (amount * 100).round(),
              category: category,
              note: widget.existing!.note,
            );
      } else {
        final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
        if (userId == null) return;
        await ref.read(financeRepositoryProvider).addExpense(
              userId: userId,
              amountCents: (amount * 100).round(),
              category: category,
            );
      }
      ref.invalidate(expensesThisMonthProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final momAvatar = ref.watch(effectiveMomAvatarProvider);
    final fieldDecoration = InputDecoration(
      filled: true,
      fillColor: mom.surface,
      hintStyle: MomText.placeholder(mom.placeholderText, size: 15),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.momGutter, vertical: AppSpacing.md),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
        borderSide: BorderSide(color: mom.espresso, width: 1.5),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, AppSpacing.md, AppSpacing.momGutter, AppSpacing.xl),
        decoration: BoxDecoration(
          color: mom.shell,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.momRadiusSheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(color: mom.fieldBorder, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill)),
              ),
            ),
            Row(
              children: [
                MomAvatar(style: momAvatar, expression: MomExpression.notes, showMoodBadge: false, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_isEditing ? 'Edit expense' : 'Log an expense', style: MomText.sheetTitle(mom.ink)),
                      Text(
                        _isEditing ? "I'll update this month's total to match." : "I'll fold it into this month's total.",
                        style: MomText.meta(mom.inkMuted, size: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _amountController,
              onChanged: (_) => setState(() {}),
              autofocus: true,
              cursorColor: mom.doneOrange,
              style: MomText.rowLabel(mom.ink, selected: true),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: fieldDecoration.copyWith(hintText: 'Amount (e.g. 12.50)'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Category', style: MomText.control(mom.inkSoft, size: 12.5)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final c in kExpenseCategories)
                  MomChip(
                    label: c,
                    selected: !_customSelected && _category == c,
                    onTap: () => setState(() {
                      _customSelected = false;
                      _category = c;
                    }),
                  ),
                MomChip(label: 'Custom', selected: _customSelected, onTap: () => setState(() => _customSelected = true)),
              ],
            ),
            if (_customSelected) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _customCategoryController,
                onChanged: (_) => setState(() {}),
                style: MomText.body(mom.ink),
                decoration: fieldDecoration.copyWith(hintText: 'Category name'),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(color: mom.shell, borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Date', style: MomText.body(mom.inkSoft)),
                  Text(DateFormat('MMM d').format(widget.existing?.spentAt ?? DateTime.now()), style: MomText.rowLabel(mom.ink)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: _saving ? 'Saving…' : (_isEditing ? 'Save changes' : 'Add expense'),
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
            try {
              await ref.read(financeRepositoryProvider).setOverallBudget(
                    userId: userId,
                    amountCents: (amount * 100).round(),
                  );
              ref.invalidate(overallBudgetCentsProvider);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(friendlyError(e))),
                );
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<void> showSetCategoryBudgetDialog(
  BuildContext context,
  WidgetRef ref, {
  required String category,
  int? currentCents,
}) {
  final controller = TextEditingController(
    text: currentCents != null ? (currentCents / 100).toStringAsFixed(0) : '',
  );
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$category budget'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: 'e.g. 200'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            final amount = double.tryParse(controller.text);
            if (amount == null || amount <= 0) return;
            final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
            if (userId == null) return;
            try {
              await ref.read(financeRepositoryProvider).setCategoryBudget(
                    userId: userId,
                    category: category,
                    amountCents: (amount * 100).round(),
                  );
              ref.invalidate(categoryBudgetsProvider);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(friendlyError(e))),
                );
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
