import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'mom_tokens.dart';
import 'mom_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(
        brightness: Brightness.light,
        background: AppColors.backgroundLight,
        surface: AppColors.surfaceLight,
        textPrimary: AppColors.textPrimaryLight,
        textSecondary: AppColors.textSecondaryLight,
        border: AppColors.borderLight,
        selectedFill: AppColors.selectedFillLight,
        selectedOnFill: AppColors.textOnAccent,
        momColors: MomColors.light,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        background: AppColors.backgroundDark,
        surface: AppColors.surfaceDark,
        textPrimary: AppColors.textPrimaryDark,
        textSecondary: AppColors.textSecondaryDark,
        border: AppColors.borderDark,
        selectedFill: AppColors.selectedFillDark,
        selectedOnFill: AppColors.selectedOnFillDark,
        momColors: MomColors.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
    required Color selectedFill,
    required Color selectedOnFill,
    required MomColors momColors,
  }) {
    final textTheme = AppTypography.textTheme(textPrimary, textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      fontFamily: textTheme.bodyMedium?.fontFamily,
      textTheme: textTheme,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.accent,
        onPrimary: AppColors.textOnAccent,
        secondary: selectedFill,
        onSecondary: selectedOnFill,
        error: AppColors.moodDisappointed,
        onError: AppColors.textOnAccent,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: momColors.espresso,
          foregroundColor: Colors.white,
          disabledBackgroundColor: momColors.espresso.withValues(alpha: 0.4),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: 17,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          textStyle: MomText.button(Colors.white),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(momColors.espressoPressed.withValues(alpha: 0.15)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      iconTheme: IconThemeData(color: textPrimary, size: 22),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      extensions: [momColors],
    );
  }
}
