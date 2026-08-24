import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/mom_mood.dart';

/// The 5 selectable Mom looks — same face underneath (she's still Mom
/// either way), just a different hairstyle silhouette and fill color.
enum MomAvatarStyle { terracotta, sage, blush, tan, charcoal }

extension MomAvatarStyleX on MomAvatarStyle {
  Color get fill => switch (this) {
        MomAvatarStyle.terracotta => const Color(0xFFD9662E),
        MomAvatarStyle.sage => const Color(0xFF7C9463),
        MomAvatarStyle.blush => const Color(0xFFCC8598),
        MomAvatarStyle.tan => const Color(0xFFB98F5E),
        MomAvatarStyle.charcoal => const Color(0xFF4A4640),
      };

  String get displayName => switch (this) {
        MomAvatarStyle.terracotta => 'Mom (Terracotta)',
        MomAvatarStyle.sage => 'Mom (Sage)',
        MomAvatarStyle.blush => 'Mom (Blush)',
        MomAvatarStyle.tan => 'Mom (Tan)',
        MomAvatarStyle.charcoal => 'Mom (Charcoal)',
      };
}

/// A small illustrated Mom face — hand-coded vector art (via
/// CustomPainter, not an image asset) rather than a generic icon.
/// Hairstyle silhouette varies by [MomAvatarStyle], expression varies
/// by [MomMood]. Flat shapes only, no gradients — matches the rest of
/// the app's design system.
class MomAvatar extends StatelessWidget {
  const MomAvatar({
    super.key,
    required this.style,
    this.mood = MomMood.neutral,
    this.size = 64,
    this.showMoodBadge = true,
  });

  final MomAvatarStyle style;
  final MomMood mood;
  final double size;
  final bool showMoodBadge;

  IconData get _moodIcon => switch (mood) {
        MomMood.proud => LucideIcons.smile,
        MomMood.neutral => LucideIcons.meh,
        MomMood.disappointed => LucideIcons.frown,
        MomMood.veryDisappointed => LucideIcons.cloudRain,
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _MomFacePainter(style: style, mood: mood),
          ),
          if (showMoodBadge)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: EdgeInsets.all(size * 0.06),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceLight,
                  border: Border.all(color: mood.color, width: 1.5),
                ),
                child: Icon(_moodIcon, size: size * 0.22, color: mood.color),
              ),
            ),
        ],
      ),
    );
  }
}

class _MomFacePainter extends CustomPainter {
  _MomFacePainter({required this.style, required this.mood});
  final MomAvatarStyle style;
  final MomMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final ringPaint = Paint()
      ..color = mood.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045;
    final facePaint = Paint()..color = style.fill;
    final featurePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;
    final eyePaint = Paint()..color = Colors.white.withValues(alpha: 0.92);

    // Head
    canvas.drawCircle(center, r - ringPaint.strokeWidth / 2, facePaint);

    // Hair silhouette, per style — clipped to the head circle so it
    // always reads as "hair", never spills outside the face.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r - ringPaint.strokeWidth / 2)));
    final hairPaint = Paint()..color = Colors.white.withValues(alpha: 0.22);
    switch (style) {
      case MomAvatarStyle.terracotta:
        // Shoulder-length: two side arcs.
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - r, center.dy - r * 0.1)
            ..quadraticBezierTo(center.dx - r * 1.05, center.dy + r, center.dx - r * 0.55, center.dy + r * 1.1)
            ..lineTo(center.dx - r * 0.85, center.dy + r * 1.1)
            ..quadraticBezierTo(center.dx - r * 1.3, center.dy + r * 0.2, center.dx - r * 0.75, center.dy - r * 0.6)
            ..close(),
          hairPaint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(center.dx + r, center.dy - r * 0.1)
            ..quadraticBezierTo(center.dx + r * 1.05, center.dy + r, center.dx + r * 0.55, center.dy + r * 1.1)
            ..lineTo(center.dx + r * 0.85, center.dy + r * 1.1)
            ..quadraticBezierTo(center.dx + r * 1.3, center.dy + r * 0.2, center.dx + r * 0.75, center.dy - r * 0.6)
            ..close(),
          hairPaint,
        );
        canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.98), 3.4, 2.7, false, hairPaint);
      case MomAvatarStyle.sage:
        // Short bob: a single top arc, ending at ear level.
        canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.98), 3.3, 2.9, false, hairPaint);
      case MomAvatarStyle.blush:
        // Curly: a ring of little bumps around the top.
        for (var i = 0; i <= 6; i++) {
          final angle = 3.3 + (i / 6) * 2.9;
          final bumpCenter = center + Offset.fromDirection(angle, r * 0.72);
          canvas.drawCircle(bumpCenter, r * 0.26, hairPaint);
        }
      case MomAvatarStyle.tan:
        // Bun: top arc plus a small circle on top.
        canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.98), 3.5, 2.5, false, hairPaint);
        canvas.drawCircle(Offset(center.dx, center.dy - r * 0.95), r * 0.3, hairPaint);
      case MomAvatarStyle.charcoal:
        // Sleek, pulled back: thin close-cropped arc.
        canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.98), 3.6, 2.3, false, hairPaint);
    }
    canvas.restore();

    // Face ring (mood color)
    canvas.drawCircle(center, r - ringPaint.strokeWidth / 2, ringPaint);

    // Expression, per mood.
    final eyeY = center.dy - r * 0.08;
    final eyeDx = r * 0.32;
    final eyeR = r * 0.07;
    switch (mood) {
      case MomMood.proud:
        // Smiling eyes: little upward arcs instead of dots.
        for (final dx in [-eyeDx, eyeDx]) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset(center.dx + dx, eyeY), radius: eyeR * 1.4),
            3.4,
            2.5,
            false,
            featurePaint,
          );
        }
        canvas.drawArc(
          Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.18), width: r * 0.7, height: r * 0.5),
          0.3,
          2.5,
          false,
          featurePaint,
        );
      case MomMood.neutral:
        canvas.drawCircle(Offset(center.dx - eyeDx, eyeY), eyeR, eyePaint);
        canvas.drawCircle(Offset(center.dx + eyeDx, eyeY), eyeR, eyePaint);
        canvas.drawLine(
          Offset(center.dx - r * 0.28, center.dy + r * 0.32),
          Offset(center.dx + r * 0.28, center.dy + r * 0.32),
          featurePaint,
        );
      case MomMood.disappointed:
        canvas.drawCircle(Offset(center.dx - eyeDx, eyeY), eyeR, eyePaint);
        canvas.drawCircle(Offset(center.dx + eyeDx, eyeY), eyeR, eyePaint);
        canvas.drawArc(
          Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.5), width: r * 0.6, height: r * 0.4),
          3.6,
          2.2,
          false,
          featurePaint,
        );
      case MomMood.veryDisappointed:
        canvas.drawCircle(Offset(center.dx - eyeDx, eyeY), eyeR, eyePaint);
        canvas.drawCircle(Offset(center.dx + eyeDx, eyeY), eyeR, eyePaint);
        // Angled eyebrows.
        canvas.drawLine(
          Offset(center.dx - eyeDx - r * 0.16, eyeY - r * 0.22),
          Offset(center.dx - eyeDx + r * 0.14, eyeY - r * 0.32),
          featurePaint,
        );
        canvas.drawLine(
          Offset(center.dx + eyeDx + r * 0.16, eyeY - r * 0.22),
          Offset(center.dx + eyeDx - r * 0.14, eyeY - r * 0.32),
          featurePaint,
        );
        canvas.drawArc(
          Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.58), width: r * 0.62, height: r * 0.4),
          3.5,
          2.4,
          false,
          featurePaint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _MomFacePainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.mood != mood;
}

/// Reopenable from Settings ("Change Mom's avatar") — same picker grid
/// as onboarding's avatar step, but persists immediately to `profiles`
/// instead of waiting for account creation.
Future<void> showMomAvatarPicker(
  BuildContext context, {
  required MomAvatarStyle current,
  required ValueChanged<MomAvatarStyle> onSelected,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _AvatarPickerSheet(current: current, onSelected: onSelected),
  );
}

class _AvatarPickerSheet extends StatelessWidget {
  const _AvatarPickerSheet({required this.current, required this.onSelected});
  final MomAvatarStyle current;
  final ValueChanged<MomAvatarStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Change Mom's look", style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              for (final style in MomAvatarStyle.values)
                GestureDetector(
                  onTap: () {
                    onSelected(style);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: current == style ? AppColors.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: MomAvatar(style: style, showMoodBadge: false, size: 56),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
