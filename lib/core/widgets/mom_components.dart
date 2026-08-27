import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_spacing.dart';
import '../theme/mom_mood.dart';
import '../theme/mom_tokens.dart';
import '../theme/mom_typography.dart';
import 'mom_avatar.dart';

/// Mom's recurring peach message card — used on every AI MOM screen.
/// Peach fill, radius 20, no shadow (peach surfaces never carry a shadow).
/// Omit this widget entirely (don't render it empty) when a screen has no
/// message state to show — never invent copy the screen doesn't have.
class MomMessageCard extends StatelessWidget {
  const MomMessageCard({
    super.key,
    required this.avatarStyle,
    required this.expression,
    required this.eyebrow,
    required this.message,
  });

  final MomAvatarStyle avatarStyle;
  final MomExpression expression;
  final String eyebrow;
  final String message;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: mom.promoPeach,
        borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanelSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MomAvatar(style: avatarStyle, expression: expression, showMoodBadge: false, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow.toUpperCase(), style: MomText.eyebrow(mom.tintIcons[0])),
                const SizedBox(height: 4),
                Text(message, style: MomText.momMessage(mom.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White stat tile: tinted icon square over a big value over a caption.
/// Used in rows of 2-3 on Home, Tasks, Track, and Financial tracking.
class MomStatCard extends StatelessWidget {
  const MomStatCard({
    super.key,
    required this.icon,
    required this.tintIndex,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final int tintIndex;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final tint = mom.tints[tintIndex % mom.tints.length];
    final tintIcon = mom.tintIcons[tintIndex % mom.tintIcons.length];
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: mom.surface,
        borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
        boxShadow: MomElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppSpacing.momRadiusTile - 1)),
            child: Icon(icon, size: 17, color: tintIcon),
          ),
          const SizedBox(height: 10),
          Text(value, style: MomText.statValue(mom.ink)),
          const SizedBox(height: 2),
          Text(caption, style: MomText.meta(mom.inkMuted)),
        ],
      ),
    );
  }
}

/// A full-width tinted task/habit row — rotates through the 5-tint
/// palette by [tintIndex] (list order, not category identity). Idle
/// check is a translucent white ring; done fills orange and strikes the
/// title through.
class MomTaskRow extends StatelessWidget {
  const MomTaskRow({
    super.key,
    required this.icon,
    required this.tintIndex,
    required this.metaLabel,
    required this.title,
    this.sub,
    required this.done,
    required this.onToggle,
  });

  final IconData icon;
  final int tintIndex;
  final String metaLabel;
  final String title;
  final String? sub;
  final bool done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final tint = mom.tints[tintIndex % mom.tints.length];
    final tintIcon = mom.tintIcons[tintIndex % mom.tintIcons.length];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard)),
      constraints: const BoxConstraints(minHeight: AppSpacing.momMinHitTarget),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: mom.taskTileFill,
              borderRadius: BorderRadius.circular(AppSpacing.momRadiusTile),
              border: Border.all(color: tintIcon.withValues(alpha: 0.2), width: 1.5),
            ),
            child: Icon(icon, size: 17, color: tintIcon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(metaLabel.toUpperCase(), style: MomText.taskMetaLabel(tintIcon)),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: MomText.taskTitle(mom.ink).copyWith(
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? mom.ink.withValues(alpha: 0.6) : mom.ink,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 1),
                  Text(sub!, style: MomText.meta(tintIcon, size: 11)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? mom.doneOrange : mom.checkIdleFill,
                border: Border.all(color: done ? mom.doneOrange : mom.checkIdleRing, width: 2),
              ),
              child: done ? const Icon(LucideIcons.check, size: 14, color: Colors.white) : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single-select option row (onboarding). Idle: white + card shadow.
/// Selected: peach fill + 1.5px espresso border, no shadow, filled check.
class MomOptionRow extends StatelessWidget {
  const MomOptionRow({
    super.key,
    required this.label,
    this.sub,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: AppSpacing.momMinHitTarget),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: selected ? mom.promoPeach : mom.surface,
          borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
          border: selected ? Border.all(color: mom.espresso, width: 1.5) : null,
          boxShadow: selected ? null : MomElevation.card,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: MomText.rowLabel(mom.ink, selected: selected)),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub!, style: MomText.rowSub(selected ? mom.selectedRowSub : mom.inkMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
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

/// A single-select/multi-select pill chip.
class MomChip extends StatelessWidget {
  const MomChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? mom.promoPeach : mom.surface,
          borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
          border: Border.all(color: selected ? mom.espresso : mom.chipBorder, width: 1.5),
        ),
        child: Text(label, style: MomText.chipLabel(mom.ink, selected: selected)),
      ),
    );
  }
}

/// A dashed-outline suggestion chip (health "add a custom activity"
/// suggestions, expense category "Custom").
class MomDashedChip extends StatelessWidget {
  const MomDashedChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: mom.fieldBorder, radius: AppSpacing.momRadiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Text(label, style: MomText.chipLabel(mom.inkSoft)),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dashWidth = 4.0;
    const gapWidth = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dashWidth), paint);
        distance += dashWidth + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// 50x30 track / 24px knob toggle. On = espresso, off = fieldBorder.
class MomToggle extends StatelessWidget {
  const MomToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? mom.espresso : mom.fieldBorder,
          borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          curve: Curves.easeOut,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// White secondary button — 1.5px fieldBorder (espresso when it's the
/// screen's main call-to-action, e.g. "Unlock with Full Mom").
class MomSecondaryButton extends StatelessWidget {
  const MomSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isMainCta = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isMainCta;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final borderColor = isMainCta ? mom.espresso : mom.fieldBorder;
    final textColor = isMainCta ? mom.espresso : mom.inkSoft;
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: mom.surface,
        foregroundColor: textColor,
        side: BorderSide(color: borderColor, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: textColor), const SizedBox(width: 8)],
          Text(label, style: MomText.button(textColor)),
        ],
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
