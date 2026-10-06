import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/utils/quiet_hours.dart';
import '../../core/widgets/mom_components.dart';

class QuietHoursChoice {
  const QuietHoursChoice({required this.enabled, required this.from, required this.until});
  final bool enabled;
  final int from;
  final int until;
}

/// Lets someone pick when Mom stays quiet. Pops with a [QuietHoursChoice] on
/// Save, or null if cancelled.
class QuietHoursDialog extends StatefulWidget {
  const QuietHoursDialog({super.key, required this.enabled, required this.from, required this.until});

  final bool enabled;
  final int from;
  final int until;

  @override
  State<QuietHoursDialog> createState() => _QuietHoursDialogState();
}

class _QuietHoursDialogState extends State<QuietHoursDialog> {
  late bool _enabled = widget.enabled;
  late int _from = widget.from;
  late int _until = widget.until;

  bool get _valid => isValidQuietWindow(enabled: _enabled, from: _from, until: _until);

  Widget _hourPicker(String label, int value, ValueChanged<int> onChanged) {
    final mom = context.mom;
    return Row(
      children: [
        Expanded(child: Text(label, style: MomText.rowLabel(_enabled ? mom.ink : mom.inkMuted))),
        DropdownButton<int>(
          value: value,
          onChanged: _enabled ? (v) => setState(() => onChanged(v!)) : null,
          items: [
            for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text(formatHour(h))),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return AlertDialog(
      title: const Text('Quiet hours'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Mom won't send nudges during these hours, in your local time. They wait until quiet hours end.",
            style: MomText.meta(mom.inkMuted, size: 12.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: Text('Quiet hours', style: MomText.rowLabel(mom.ink))),
              MomToggle(value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _hourPicker('From', _from, (v) => _from = v),
          _hourPicker('Until', _until, (v) => _until = v),
          if (!_valid) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Pick two different times.', style: MomText.meta(mom.danger, size: 12)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Reminders you set on a task still ring at their time.",
            style: MomText.meta(mom.inkMuted, size: 11.5),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: _valid ? () => Navigator.pop(context, QuietHoursChoice(enabled: _enabled, from: _from, until: _until)) : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
