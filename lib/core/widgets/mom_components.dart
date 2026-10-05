import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
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
    this.onTap,
  });

  final IconData icon;
  final int tintIndex;
  final String metaLabel;
  final String title;
  final String? sub;
  final bool done;
  final VoidCallback onToggle;

  /// Opens editing for this task — tapping the row anywhere except the
  /// checkbox itself (which keeps its own [onToggle] instead).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final tint = mom.tints[tintIndex % mom.tints.length];
    final tintIcon = mom.tintIcons[tintIndex % mom.tintIcons.length];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
      child: AnimatedContainer(
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
                    // Fixed (not brightness-dependent) — this row always sits on a
                    // light tint fill, which never flips color in dark mode.
                    style: MomText.taskTitle(AppColors.ink).copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? AppColors.ink.withValues(alpha: 0.6) : AppColors.ink,
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
/// Google's four-colour "G", inline so there's no asset file to ship or lose.
const _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';

/// "Continue with Google" / "Continue with Apple". These used to be
/// [MomSecondaryButton]s, which is built to sit quietly next to a main
/// action: a faint outline and pale text, plus a generic globe icon. Next
/// to the dark main button that read as greyed out and disabled, and as
/// not obviously Google. This one keeps the same shape but uses dark text,
/// a clearly visible border and the real brand logo, and only looks muted
/// when it genuinely is disabled (for example while a sign-in is running).
class MomSocialButton extends StatelessWidget {
  const MomSocialButton.google({super.key, required this.onPressed, this.label = 'Continue with Google'})
      : _isGoogle = true;
  const MomSocialButton.apple({super.key, required this.onPressed, this.label = 'Continue with Apple'})
      : _isGoogle = false;

  final String label;
  final VoidCallback? onPressed;
  final bool _isGoogle;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final enabled = onPressed != null;
    final textColor = enabled ? mom.ink : mom.inkMuted;
    final logo = _isGoogle
        ? SvgPicture.string(_googleLogoSvg, width: 20, height: 20)
        : Icon(LucideIcons.apple, size: 20, color: textColor);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: mom.surface,
          foregroundColor: mom.ink,
          side: BorderSide(color: enabled ? mom.espresso : mom.fieldBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(opacity: enabled ? 1 : 0.45, child: logo),
            const SizedBox(width: 10),
            Text(label, style: MomText.button(textColor)),
          ],
        ),
      ),
    );
  }
}

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
