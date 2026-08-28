import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/task_item.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/mom_components.dart';
import '../../core/widgets/primary_button.dart';

/// Bottom sheet to add a task or habit. Recurrence is just a field on
/// the same form — see the planning note that tasks and habits are one
/// entity, not two features.
///
/// [forDay] is whichever calendar day is currently selected on the
/// screen the sheet was opened from — a one-off task belongs to its
/// `created_at` day, so without this it would always land on today even
/// while browsing a different day.
Future<void> showAddTaskSheet(BuildContext context, {DateTime? forDay}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AddTaskSheet(forDay: forDay),
  );
}

class _AddTaskSheet extends ConsumerStatefulWidget {
  const _AddTaskSheet({this.forDay});

  final DateTime? forDay;

  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  final _titleController = TextEditingController();
  final _customCategoryController = TextEditingController();
  TaskCategory _category = TaskCategory.personal;
  bool _customSelected = false;
  RecurrenceType _recurrence = RecurrenceType.none;
  TimeOfDay? _dueTime;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_titleController.text.trim().isEmpty) return false;
    if (_customSelected && _customCategoryController.text.trim().isEmpty) return false;
    return true;
  }

  String? get _dueTimeString {
    final t = _dueTime;
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _pickDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      final target = widget.forDay;
      final now = DateTime.now();
      final isTargetToday = target == null ||
          (target.year == now.year && target.month == now.month && target.day == now.day);
      final taskId = await ref.read(tasksProvider.notifier).addTask(
            title: title,
            category: _customSelected ? _customCategoryController.text.trim() : _category.name,
            recurrence: _recurrence,
            dueTime: _dueTimeString,
            createdAt: isTargetToday
                ? null
                : DateTime(target.year, target.month, target.day, now.hour, now.minute, now.second),
          );
      if (taskId != null && _dueTimeString != null) {
        await NotificationService.scheduleTaskReminder(
          taskId: taskId,
          title: title,
          dueTime: _dueTimeString!,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('addTask failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final fieldDecoration = InputDecoration(
      filled: true,
      fillColor: mom.surface,
      hintStyle: MomText.placeholder(mom.placeholderText),
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
            Text('New task', style: MomText.sheetTitle(mom.ink)),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _titleController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              style: MomText.body(mom.ink),
              decoration: fieldDecoration.copyWith(hintText: 'What needs doing?'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Category', style: MomText.control(mom.inkSoft, size: 12.5)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final c in TaskCategory.values.where((c) => c != TaskCategory.other))
                  MomChip(
                    label: c.label,
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
                textCapitalization: TextCapitalization.words,
                style: MomText.body(mom.ink),
                decoration: fieldDecoration.copyWith(hintText: 'Category name'),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text('Repeat', style: MomText.control(mom.inkSoft, size: 12.5)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final r in RecurrenceType.values.where((r) => r != RecurrenceType.custom))
                  MomChip(
                    label: switch (r) {
                      RecurrenceType.none => 'One-off',
                      RecurrenceType.daily => 'Daily',
                      RecurrenceType.weekly => 'Weekly',
                      RecurrenceType.custom => 'Custom',
                    },
                    selected: _recurrence == r,
                    onTap: () => setState(() => _recurrence = r),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Reminder', style: MomText.control(mom.inkSoft, size: 12.5)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                MomChip(
                  label: _dueTime == null ? 'No reminder' : 'Remind me at ${_dueTime!.format(context)}',
                  selected: _dueTime != null,
                  onTap: _pickDueTime,
                ),
                if (_dueTime != null)
                  MomChip(label: 'Clear', selected: false, onTap: () => setState(() => _dueTime = null)),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: _saving ? 'Saving…' : 'Add task',
              onPressed: (_canSave && !_saving) ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}
