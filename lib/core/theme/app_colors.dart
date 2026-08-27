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

  // ---------------------------------------------------------------------
  // AI MOM light system — the design-handoff token set (Aug 2026 redesign
  // of Tasks/Chat/Track/Paywall/Settings + onboarding/Home). Screens are
  // migrated to this set one at a time; the block above stays until every
  // screen no longer references it.
  // ---------------------------------------------------------------------

  static const Color shell = Color(0xFFF7EDEA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color promoPeach = Color(0xFFF9D5B8);

  static const Color ink = Color(0xFF221E1E);
  static const Color inkSoft = Color(0xFF7A6A64);
  static const Color inkMuted = Color(0xFF9A8C86);
  static const Color placeholderText = Color(0xFFC0B0A9);

  static const Color hairline = Color(0xFFF3EAE7);
  static const Color fieldBorder = Color(0xFFE7D6CE);
  static const Color chipBorder = Color(0xFFEFE0D8);
  static const Color checkIdleBorder = Color(0xFFDCCFC9);

  static const Color espresso = Color(0xFF5C3317);
  static const Color espressoPressed = Color(0xFF45230D);
  static const Color doneOrange = Color(0xFFF0812F);
  static const Color peachOnPeach = Color(0xFFE6C6A8);
  static const Color peachPanelMuted = Color(0xFF7C5A44);

  static const Color danger = Color(0xFFB23A20);
  static const Color dangerChevron = Color(0xFFD3A093);

  static const Color navInactive = Color(0xFFB5A6A0);

  /// Sub-label color on a selected peach option row (onboarding routine
  /// step) — warmer than the generic inkMuted so it still reads on peach.
  static const Color selectedRowSub = Color(0xFF8A6A52);

  /// Idle (unchecked) completion-check fill/border — 0.75/0.22-alpha
  /// espresso used on both Home and Tasks task rows.
  static Color get checkIdleFill => Colors.white.withValues(alpha: 0.75);
  static Color get checkIdleRing => espresso.withValues(alpha: 0.22);

  /// Semi-opaque white tile background used inside tinted task rows.
  static Color get taskTileFill => Colors.white.withValues(alpha: 0.7);

  /// The 5-tint rotation for task/category tiles (peach, mint, lilac,
  /// pink, blue, in that order) and the matching glyph/meta-label color
  /// for each. Index by `index % tints.length` in list order.
  static const List<Color> tints = [
    Color(0xFFFCE0C6),
    Color(0xFFE4EFC0),
    Color(0xFFF8DCF3),
    Color(0xFFFBDDE3),
    Color(0xFFD9E8EE),
  ];
  static const List<Color> tintIcons = [
    Color(0xFFB4611F),
    Color(0xFF6C8231),
    Color(0xFFA2549A),
    Color(0xFFC05874),
    Color(0xFF3F7C93),
  ];

  // Dark-mode counterparts. The design handoff is light-only; these are a
  // best-effort derived dark palette so Settings' Appearance (System /
  // Light / Dark) keeps working rather than being removed.
  static const Color shellDark = Color(0xFF1C1815);
  static const Color surfaceDarkNew = Color(0xFF262019);
  static const Color promoPeachDark = Color(0xFF4A3020);

  static const Color inkDark = Color(0xFFF3EAE6);
  static const Color inkSoftDark = Color(0xFFC7B8B1);
  static const Color inkMutedDark = Color(0xFF9C8D86);
  static const Color placeholderTextDark = Color(0xFF6E6058);

  static const Color hairlineDark = Color(0xFF332B25);
  static const Color fieldBorderDark = Color(0xFF3D332B);
  static const Color chipBorderDark = Color(0xFF3D332B);
  static const Color checkIdleBorderDark = Color(0xFF4C4038);

  static const Color espressoDarkAccent = Color(0xFFE0A879);
  static const Color espressoPressedDarkAccent = Color(0xFFF0C39C);
  static const Color doneOrangeDark = Color(0xFFF0812F);
  static const Color peachOnPeachDark = Color(0xFF5E432E);

  static const Color dangerDark = Color(0xFFE8654A);
  static const Color dangerChevronDark = Color(0xFF8C5C4D);
  static const Color navInactiveDark = Color(0xFF6E6058);
  static const Color selectedRowSubDark = Color(0xFFD9C2AE);
}
