import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The AI MOM light-system color tokens, registered as a [ThemeExtension]
/// so every screen reads `context.mom.xxx` — brightness-aware, no manual
/// `Theme.of(context).brightness == Brightness.dark` branching in call sites.
class MomColors extends ThemeExtension<MomColors> {
  const MomColors({
    required this.shell,
    required this.surface,
    required this.promoPeach,
    required this.ink,
    required this.inkSoft,
    required this.inkMuted,
    required this.placeholderText,
    required this.hairline,
    required this.fieldBorder,
    required this.chipBorder,
    required this.checkIdleBorder,
    required this.espresso,
    required this.espressoPressed,
    required this.doneOrange,
    required this.peachOnPeach,
    required this.peachPanelMuted,
    required this.danger,
    required this.dangerChevron,
    required this.navInactive,
    required this.checkIdleFill,
    required this.checkIdleRing,
    required this.taskTileFill,
    required this.tints,
    required this.tintIcons,
  });

  final Color shell;
  final Color surface;
  final Color promoPeach;
  final Color ink;
  final Color inkSoft;
  final Color inkMuted;
  final Color placeholderText;
  final Color hairline;
  final Color fieldBorder;
  final Color chipBorder;
  final Color checkIdleBorder;
  final Color espresso;
  final Color espressoPressed;
  final Color doneOrange;
  final Color peachOnPeach;
  final Color peachPanelMuted;
  final Color danger;
  final Color dangerChevron;
  final Color navInactive;
  final Color checkIdleFill;
  final Color checkIdleRing;
  final Color taskTileFill;
  final List<Color> tints;
  final List<Color> tintIcons;

  static const light = MomColors(
    shell: AppColors.shell,
    surface: AppColors.surface,
    promoPeach: AppColors.promoPeach,
    ink: AppColors.ink,
    inkSoft: AppColors.inkSoft,
    inkMuted: AppColors.inkMuted,
    placeholderText: AppColors.placeholderText,
    hairline: AppColors.hairline,
    fieldBorder: AppColors.fieldBorder,
    chipBorder: AppColors.chipBorder,
    checkIdleBorder: AppColors.checkIdleBorder,
    espresso: AppColors.espresso,
    espressoPressed: AppColors.espressoPressed,
    doneOrange: AppColors.doneOrange,
    peachOnPeach: AppColors.peachOnPeach,
    peachPanelMuted: AppColors.peachPanelMuted,
    danger: AppColors.danger,
    dangerChevron: AppColors.dangerChevron,
    navInactive: AppColors.navInactive,
    checkIdleFill: Color(0xBFFFFFFF),
    checkIdleRing: Color(0x385C3317),
    taskTileFill: Color(0xB3FFFFFF),
    tints: AppColors.tints,
    tintIcons: AppColors.tintIcons,
  );

  static const dark = MomColors(
    shell: AppColors.shellDark,
    surface: AppColors.surfaceDarkNew,
    promoPeach: AppColors.promoPeachDark,
    ink: AppColors.inkDark,
    inkSoft: AppColors.inkSoftDark,
    inkMuted: AppColors.inkMutedDark,
    placeholderText: AppColors.placeholderTextDark,
    hairline: AppColors.hairlineDark,
    fieldBorder: AppColors.fieldBorderDark,
    chipBorder: AppColors.chipBorderDark,
    checkIdleBorder: AppColors.checkIdleBorderDark,
    espresso: AppColors.espressoDarkAccent,
    espressoPressed: AppColors.espressoPressedDarkAccent,
    doneOrange: AppColors.doneOrangeDark,
    peachOnPeach: AppColors.peachOnPeachDark,
    peachPanelMuted: AppColors.inkMutedDark,
    danger: AppColors.dangerDark,
    dangerChevron: AppColors.dangerChevronDark,
    navInactive: AppColors.navInactiveDark,
    checkIdleFill: Color(0x40FFFFFF),
    checkIdleRing: Color(0x59E0A879),
    taskTileFill: Color(0x26FFFFFF),
    tints: AppColors.tints,
    tintIcons: AppColors.tintIcons,
  );

  @override
  MomColors copyWith({
    Color? shell,
    Color? surface,
    Color? promoPeach,
    Color? ink,
    Color? inkSoft,
    Color? inkMuted,
    Color? placeholderText,
    Color? hairline,
    Color? fieldBorder,
    Color? chipBorder,
    Color? checkIdleBorder,
    Color? espresso,
    Color? espressoPressed,
    Color? doneOrange,
    Color? peachOnPeach,
    Color? peachPanelMuted,
    Color? danger,
    Color? dangerChevron,
    Color? navInactive,
    Color? checkIdleFill,
    Color? checkIdleRing,
    Color? taskTileFill,
    List<Color>? tints,
    List<Color>? tintIcons,
  }) {
    return MomColors(
      shell: shell ?? this.shell,
      surface: surface ?? this.surface,
      promoPeach: promoPeach ?? this.promoPeach,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      inkMuted: inkMuted ?? this.inkMuted,
      placeholderText: placeholderText ?? this.placeholderText,
      hairline: hairline ?? this.hairline,
      fieldBorder: fieldBorder ?? this.fieldBorder,
      chipBorder: chipBorder ?? this.chipBorder,
      checkIdleBorder: checkIdleBorder ?? this.checkIdleBorder,
      espresso: espresso ?? this.espresso,
      espressoPressed: espressoPressed ?? this.espressoPressed,
      doneOrange: doneOrange ?? this.doneOrange,
      peachOnPeach: peachOnPeach ?? this.peachOnPeach,
      peachPanelMuted: peachPanelMuted ?? this.peachPanelMuted,
      danger: danger ?? this.danger,
      dangerChevron: dangerChevron ?? this.dangerChevron,
      navInactive: navInactive ?? this.navInactive,
      checkIdleFill: checkIdleFill ?? this.checkIdleFill,
      checkIdleRing: checkIdleRing ?? this.checkIdleRing,
      taskTileFill: taskTileFill ?? this.taskTileFill,
      tints: tints ?? this.tints,
      tintIcons: tintIcons ?? this.tintIcons,
    );
  }

  @override
  MomColors lerp(ThemeExtension<MomColors>? other, double t) {
    if (other is! MomColors) return this;
    return MomColors(
      shell: Color.lerp(shell, other.shell, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      promoPeach: Color.lerp(promoPeach, other.promoPeach, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      placeholderText: Color.lerp(placeholderText, other.placeholderText, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      fieldBorder: Color.lerp(fieldBorder, other.fieldBorder, t)!,
      chipBorder: Color.lerp(chipBorder, other.chipBorder, t)!,
      checkIdleBorder: Color.lerp(checkIdleBorder, other.checkIdleBorder, t)!,
      espresso: Color.lerp(espresso, other.espresso, t)!,
      espressoPressed: Color.lerp(espressoPressed, other.espressoPressed, t)!,
      doneOrange: Color.lerp(doneOrange, other.doneOrange, t)!,
      peachOnPeach: Color.lerp(peachOnPeach, other.peachOnPeach, t)!,
      peachPanelMuted: Color.lerp(peachPanelMuted, other.peachPanelMuted, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerChevron: Color.lerp(dangerChevron, other.dangerChevron, t)!,
      navInactive: Color.lerp(navInactive, other.navInactive, t)!,
      checkIdleFill: Color.lerp(checkIdleFill, other.checkIdleFill, t)!,
      checkIdleRing: Color.lerp(checkIdleRing, other.checkIdleRing, t)!,
      taskTileFill: Color.lerp(taskTileFill, other.taskTileFill, t)!,
      tints: t < 0.5 ? tints : other.tints,
      tintIcons: t < 0.5 ? tintIcons : other.tintIcons,
    );
  }
}

/// Box shadows for the AI MOM light system. Same values regardless of
/// brightness — the handoff only specifies a light-mode elevation scale.
class MomElevation {
  MomElevation._();

  static const card = [BoxShadow(color: Color(0x383A1E14), offset: Offset(0, 2), blurRadius: 14, spreadRadius: -8)];
  static const fab = [BoxShadow(color: Color(0x993A1E14), offset: Offset(0, 6), blurRadius: 16, spreadRadius: -8)];
  static const nav = [BoxShadow(color: Color(0x803A1E14), offset: Offset(0, -6), blurRadius: 24, spreadRadius: -18)];
  static const modal = [BoxShadow(color: Color(0x993A1E14), offset: Offset(0, 20), blurRadius: 50, spreadRadius: -24)];
  static const avatarHero = [BoxShadow(color: Color(0x803A1E14), offset: Offset(0, 12), blurRadius: 30, spreadRadius: -16)];
}

extension MomThemeX on BuildContext {
  MomColors get mom => Theme.of(this).extension<MomColors>() ?? MomColors.light;
}
