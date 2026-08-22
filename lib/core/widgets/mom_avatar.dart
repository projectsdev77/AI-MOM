import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/mom_mood.dart';

/// The 5 selectable Mom looks. Every user's Mom is still just "Mom" —
/// this only changes her avatar color/mark, never her persona.
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

/// Placeholder Mom avatar: a solid-fill circle in the chosen style with a
/// mood-colored ring and a small expression badge. Swap the `child` for
/// real illustrated art per style/mood later without touching call sites.
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
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: style.fill,
              border: Border.all(color: mood.color, width: size * 0.045),
            ),
            alignment: Alignment.center,
            child: Icon(
              LucideIcons.heart,
              color: Colors.white.withValues(alpha: 0.9),
              size: size * 0.36,
            ),
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
