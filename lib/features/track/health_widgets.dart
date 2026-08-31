import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_state_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/track_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_mood.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/mom_avatar.dart';
import '../../core/widgets/mom_components.dart';
import '../../core/widgets/primary_button.dart';

/// Shown the first time the user opens the Health tab (no `health_goals`
/// row yet) and reachable again later to change targets.
Future<void> showHealthGoalsDialog(
  BuildContext context,
  WidgetRef ref, {
  int waterTarget = 8,
  double sleepTargetHours = 8,
  int workoutTargetMinutes = 30,
}) {
  final waterController = TextEditingController(text: waterTarget.toString());
  final sleepController = TextEditingController(text: sleepTargetHours.toString());
  final workoutController = TextEditingController(text: workoutTargetMinutes.toString());

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Set your health goals'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: waterController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Glasses of water a day'),
          ),
          TextField(
            controller: sleepController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Hours of sleep a night'),
          ),
          TextField(
            controller: workoutController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minutes of movement a day'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
            if (userId == null) return;
            try {
              await ref.read(healthRepositoryProvider).setGoals(
                    userId: userId,
                    waterTarget: int.tryParse(waterController.text) ?? 8,
                    sleepTargetHours: double.tryParse(sleepController.text) ?? 8,
                    workoutTargetMinutes: int.tryParse(workoutController.text) ?? 30,
                  );
              ref.invalidate(healthGoalsProvider);
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

/// A single-field "log this one thing" dialog — used for sleep, and for
/// movement minutes, from the "+" on their respective Health cards.
Future<void> showQuickLogDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String hint,
  required bool isDecimal,
  required Future<void> Function(num value) onSave,
}) {
  final controller = TextEditingController();
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            final value = num.tryParse(controller.text);
            if (value == null || value < 0) return;
            try {
              await onSave(value);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<void> showLogSleepSheet(BuildContext context, WidgetRef ref) {
  return showQuickLogDialog(
    context,
    ref,
    title: 'Log sleep',
    hint: 'Hours of sleep last night',
    isDecimal: true,
    onSave: (value) async {
      final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (userId == null) return;
      await ref.read(healthRepositoryProvider).logToday(userId: userId, sleepHours: value.toDouble());
      ref.invalidate(healthTodayProvider);
    },
  );
}

/// The dedicated "Log water" dialog opened by the water metric card's
/// plus button — a staged count (starting at today's total) that quick-add
/// pills or manual typing adjust, committed as one absolute [logToday]
/// call on Save (same semantics as before: the count is set, not added).
Future<void> showLogWaterDialog(BuildContext context, WidgetRef ref, {required int currentCount}) {
  return showDialog(
    context: context,
    barrierColor: context.mom.ink.withValues(alpha: 0.32),
    builder: (context) => _LogWaterDialog(currentCount: currentCount),
  );
}

class _LogWaterDialog extends ConsumerStatefulWidget {
  const _LogWaterDialog({required this.currentCount});
  final int currentCount;

  @override
  ConsumerState<_LogWaterDialog> createState() => _LogWaterDialogState();
}

class _LogWaterDialogState extends ConsumerState<_LogWaterDialog> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.currentCount}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addPill(int delta) {
    final value = int.tryParse(_controller.text) ?? widget.currentCount;
    setState(() => _controller.text = '${(value + delta).clamp(0, 999)}');
  }

  Future<void> _save() async {
    final value = int.tryParse(_controller.text);
    if (value == null || value < 0) return;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(healthRepositoryProvider).logToday(userId: userId, waterCount: value);
      ref.invalidate(healthTodayProvider);
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanel), boxShadow: MomElevation.modal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MomAvatar(style: momAvatar, expression: MomExpression.happy, showMoodBadge: false, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Log water', style: MomText.sheetTitle(mom.ink)),
                      Text('Every glass counts.', style: MomText.meta(mom.inkMuted, size: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Glasses of water', style: MomText.control(mom.inkSoft, size: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              cursorColor: mom.doneOrange,
              style: MomText.screenTitle(mom.ink).copyWith(fontSize: 28),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: UnderlineInputBorder(borderSide: BorderSide(color: mom.doneOrange, width: 2)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: mom.doneOrange, width: 2)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: mom.doneOrange, width: 2)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (final delta in [1, 2, 4]) ...[
                  if (delta != 1) const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _addPill(delta),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: mom.shell, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill)),
                      child: Text('+$delta', style: MomText.control(mom.ink, size: 12.5)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: MomSecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(context)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PrimaryButton(label: _saving ? 'Saving…' : 'Save', onPressed: _saving ? null : _save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showLogWorkoutSheet(BuildContext context, WidgetRef ref) {
  return showQuickLogDialog(
    context,
    ref,
    title: 'Log movement',
    hint: 'Minutes today',
    isDecimal: false,
    onSave: (value) async {
      final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (userId == null) return;
      await ref.read(healthRepositoryProvider).logToday(userId: userId, workoutMinutes: value.toInt());
      ref.invalidate(healthTodayProvider);
    },
  );
}

Future<void> showLogActivityMinutesSheet(
  BuildContext context,
  WidgetRef ref, {
  required String activityId,
  required String title,
}) {
  return showQuickLogDialog(
    context,
    ref,
    title: 'Log $title',
    hint: 'Minutes today',
    isDecimal: false,
    onSave: (value) async {
      final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (userId == null) return;
      await ref
          .read(healthRepositoryProvider)
          .logActivityMinutes(activityId: activityId, userId: userId, minutes: value.toInt());
      ref.invalidate(healthActivitiesProvider);
    },
  );
}

Future<void> showAddHealthActivitySheet(BuildContext context, {String? initialTitle}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AddHealthActivitySheet(initialTitle: initialTitle),
  );
}

class _AddHealthActivitySheet extends ConsumerStatefulWidget {
  const _AddHealthActivitySheet({this.initialTitle});
  final String? initialTitle;

  @override
  ConsumerState<_AddHealthActivitySheet> createState() => _AddHealthActivitySheetState();
}

class _AddHealthActivitySheetState extends ConsumerState<_AddHealthActivitySheet> {
  late final _titleController = TextEditingController(text: widget.initialTitle ?? '');
  final _targetController = TextEditingController(text: '30');
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final target = int.tryParse(_targetController.text) ?? 30;
    if (title.isEmpty) return;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(healthRepositoryProvider).addActivity(userId: userId, title: title, targetMinutes: target);
      ref.invalidate(healthActivitiesProvider);
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
        padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, AppSpacing.lg, AppSpacing.momGutter, AppSpacing.xl),
        decoration: BoxDecoration(
          color: mom.shell,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.momRadiusSheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New activity', style: MomText.sheetTitle(mom.ink)),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _titleController,
              autofocus: true,
              style: MomText.body(mom.ink),
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDecoration.copyWith(hintText: 'e.g. Tennis'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _targetController,
              style: MomText.body(mom.ink),
              keyboardType: TextInputType.number,
              decoration: fieldDecoration.copyWith(hintText: 'Goal, in minutes a day'),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: _saving ? 'Saving…' : 'Add activity',
              onPressed: (_titleController.text.trim().isEmpty || _saving) ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
