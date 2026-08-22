import 'package:flutter/material.dart';

/// AI Mom design system colors.
///
/// Warm, human palette centered on burnt-orange/terracotta with pastel
/// category chips. Deliberately avoids purple/violet gradients and glass
/// effects — flat, high-contrast surfaces instead.
class AppColors {
  AppColors._();

  // Backdrop (behind cards) — warm off-white, never a gradient.
  static const Color backgroundLight = Color(0xFFF5F1EC);
  static const Color backgroundDark = Color(0xFF17140F);

  // Card / content surfaces.
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceAltLight = Color(0xFFFAF9F7);
  static const Color surfaceDark = Color(0xFF23201A);
  static const Color surfaceAltDark = Color(0xFF2B2721);

  // Primary accent — burnt orange / terracotta.
  static const Color accent = Color(0xFFD9662E);
  static const Color accentPressed = Color(0xFFC1541F);

  // Secondary accent chips (one per category), soft pastel tints.
  static const Color chipPeach = Color(0xFFF5D9C0);
  static const Color chipSage = Color(0xFFD6E4C8);
  static const Color chipBlush = Color(0xFFF3D9E0);
  static const Color chipTan = Color(0xFFEAD9C4);

  // Dark-mode chip variants — muted/desaturated so pastels don't glow.
  static const Color chipPeachDark = Color(0xFF4A3A2C);
  static const Color chipSageDark = Color(0xFF33402C);
  static const Color chipBlushDark = Color(0xFF473139);
  static const Color chipTanDark = Color(0xFF433A2C);

  // Text — light mode.
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF8A8A8A);

  // Text — dark mode.
  static const Color textPrimaryDark = Color(0xFFF3F1EE);
  static const Color textSecondaryDark = Color(0xFFA3998C);

  static const Color textOnAccent = Color(0xFFFFFFFF);

  // Selected/active state — solid near-black, high-contrast pop.
  static const Color selectedFillLight = Color(0xFF1C1C1C);
  static const Color selectedFillDark = Color(0xFFF3F1EE);
  static const Color selectedOnFillDark = Color(0xFF1C1C1C);

  static const Color borderLight = Color(0xFFE9E3DB);
  static const Color borderDark = Color(0xFF3A352C);

  // Mom mood colors — used sparingly (avatar state ring / mood badge only).
  static const Color moodHappy = Color(0xFF6E8F4E);
  static const Color moodNeutral = Color(0xFFB8894A);
  static const Color moodDisappointed = Color(0xFFC1541F);
  static const Color moodVeryDisappointed = Color(0xFF8E3A1F);
}
