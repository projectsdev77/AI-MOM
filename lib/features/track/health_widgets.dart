import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/service_providers.dart';
import '../../core/providers/track_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
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
            await ref.read(healthRepositoryProvider).setGoals(
                  userId: userId,
                  waterTarget: int.tryParse(waterController.text) ?? 8,
                  sleepTargetHours: double.tryParse(sleepController.text) ?? 8,
                  workoutTargetMinutes: int.tryParse(workoutController.text) ?? 30,
                );
            ref.invalidate(healthGoalsProvider);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<void> showLogHealthSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _LogHealthSheet(),
  );
}

class _LogHealthSheet extends ConsumerStatefulWidget {
  const _LogHealthSheet();

  @override
  ConsumerState<_LogHealthSheet> createState() => _LogHealthSheetState();
}

class _LogHealthSheetState extends ConsumerState<_LogHealthSheet> {
  final _sleepController = TextEditingController();
  final _workoutController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _sleepController.dispose();
    _workoutController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(healthRepositoryProvider).logToday(
            userId: userId,
            sleepHours: double.tryParse(_sleepController.text),
            workoutMinutes: int.tryParse(_workoutController.text),
          );
      ref.invalidate(healthTodayProvider);
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
            Text("Log today's sleep & movement", style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _sleepController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: fieldDecoration.copyWith(hintText: 'Hours of sleep last night'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _workoutController,
              keyboardType: TextInputType.number,
              decoration: fieldDecoration.copyWith(hintText: 'Minutes of movement today'),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: _saving ? 'Saving...' : 'Save',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
