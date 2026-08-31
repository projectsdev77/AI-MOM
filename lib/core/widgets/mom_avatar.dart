import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/mom_mood.dart';
import '../theme/mom_tokens.dart';
import '../theme/mom_typography.dart';

/// The 5 selectable Mom looks. `terracotta`/`sage`/etc. are persisted
/// verbatim as `profiles.mom_avatar_style` in Supabase — the enum names
/// must never change. [svgLook] maps each to one of the 5 illustrated
/// looks in the design handoff; per the handoff, that internal look
/// identifier (e.g. "auntie-su") must never be surfaced in UI.
enum MomAvatarStyle { terracotta, sage, blush, tan, charcoal }

extension MomAvatarStyleX on MomAvatarStyle {
  String get svgLook => switch (this) {
        MomAvatarStyle.terracotta => 'auntie-su',
        MomAvatarStyle.sage => 'mama-jo',
        MomAvatarStyle.blush => 'mum-elle',
        MomAvatarStyle.tan => 'nana-rose',
        MomAvatarStyle.charcoal => 'oma-greta',
      };
}

extension MomExpressionX on MomExpression {
  String get svgSuffix => switch (this) {
        MomExpression.happy => 'happy',
        MomExpression.normal => 'normal',
        MomExpression.mad => 'mad',
        MomExpression.notes => 'notes',
      };
}

/// Mom's illustrated avatar — real art from the design handoff (25 flat
/// SVGs: 5 looks x happy/normal/mad/notes), replacing the earlier
/// hand-painted placeholder. [mood] picks the expression by default;
/// pass [expression] to force a specific one regardless of mood (e.g. a
/// screen that always shows "notes").
class MomAvatar extends StatelessWidget {
  const MomAvatar({
    super.key,
    required this.style,
    this.mood = MomMood.neutral,
    this.expression,
    this.size = 64,
    this.showMoodBadge = true,
  });

  final MomAvatarStyle style;
  final MomMood mood;
  final MomExpression? expression;
  final double size;
  final bool showMoodBadge;

  MomExpression get _resolvedExpression => expression ?? mood.expression;

  IconData get _moodIcon => switch (mood) {
        MomMood.proud => LucideIcons.smile,
        MomMood.neutral => LucideIcons.meh,
        MomMood.disappointed => LucideIcons.frown,
        MomMood.veryDisappointed => LucideIcons.cloudRain,
      };

  @override
  Widget build(BuildContext context) {
    final assetPath = 'assets/mom/svg/ai-mom-${style.svgLook}-${_resolvedExpression.svgSuffix}.svg';
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: SvgPicture.asset(
              assetPath,
              width: size,
              height: size,
              fit: BoxFit.cover,
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
    final mom = context.mom;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: mom.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Change Mom's look", style: MomText.cardTitle(mom.ink)),
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
                        color: current == style ? mom.espresso : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: current == style
                          ? [BoxShadow(color: mom.promoPeach, blurRadius: 0, spreadRadius: 4)]
                          : null,
                    ),
                    child: Opacity(
                      opacity: current == style ? 1 : 0.72,
                      child: MomAvatar(
                        style: style,
                        expression: current == style ? MomExpression.happy : MomExpression.normal,
                        showMoodBadge: false,
                        size: 56,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
