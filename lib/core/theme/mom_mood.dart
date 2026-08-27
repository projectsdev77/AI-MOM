import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The four moods Mom's avatar and dashboard message can be in.
///
/// Driven by a rolling completion score, not chosen by the user.
enum MomMood { proud, neutral, disappointed, veryDisappointed }

extension MomMoodX on MomMood {
  String get label => switch (this) {
        MomMood.proud => 'Proud of you',
        MomMood.neutral => 'Keeping an eye on you',
        MomMood.disappointed => 'A little disappointed',
        MomMood.veryDisappointed => 'Very disappointed',
      };

  Color get color => switch (this) {
        MomMood.proud => AppColors.moodHappy,
        MomMood.neutral => AppColors.moodNeutral,
        MomMood.disappointed => AppColors.moodDisappointed,
        MomMood.veryDisappointed => AppColors.moodVeryDisappointed,
      };

  /// Emoji-free expression glyph shown on the avatar ring until real art
  /// lands — kept intentionally minimal, never used as a UI icon.
  String get expressionAsset => switch (this) {
        MomMood.proud => 'assets/mom/expression_proud.png',
        MomMood.neutral => 'assets/mom/expression_neutral.png',
        MomMood.disappointed => 'assets/mom/expression_disappointed.png',
        MomMood.veryDisappointed =>
          'assets/mom/expression_very_disappointed.png',
      };

  /// The avatar-art expression the score-driven mood renders as. There's
  /// no art more severe than "mad", so both negative mood levels share it.
  MomExpression get expression => switch (this) {
        MomMood.proud => MomExpression.happy,
        MomMood.neutral => MomExpression.normal,
        MomMood.disappointed => MomExpression.mad,
        MomMood.veryDisappointed => MomExpression.mad,
      };
}

/// The 4 avatar-art expressions in the design system's SVG set. Distinct
/// from [MomMood]: mood is score-driven, expression is what's actually
/// drawn — some screens (a log dialog, a summary card) need "notes" or a
/// specific expression regardless of the current rolling mood.
enum MomExpression { happy, normal, mad, notes }
