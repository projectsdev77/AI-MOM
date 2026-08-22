import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum ChipTint { peach, sage, blush, tan }

extension _ChipTintColor on ChipTint {
  Color light() => switch (this) {
        ChipTint.peach => AppColors.chipPeach,
        ChipTint.sage => AppColors.chipSage,
        ChipTint.blush => AppColors.chipBlush,
        ChipTint.tan => AppColors.chipTan,
      };

  Color dark() => switch (this) {
        ChipTint.peach => AppColors.chipPeachDark,
        ChipTint.sage => AppColors.chipSageDark,
        ChipTint.blush => AppColors.chipBlushDark,
        ChipTint.tan => AppColors.chipTanDark,
      };
}

/// A round pastel-tinted icon badge used to mark a task/habit category.
///
/// This is the icon language for the app — a proper icon set inside a
/// tinted circle, never an emoji standing in for an icon.
class CategoryIconBadge extends StatelessWidget {
  const CategoryIconBadge({
    super.key,
    required this.icon,
    required this.tint,
    this.size = 40,
  });

  final IconData icon;
  final ChipTint tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? tint.dark() : tint.light();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(
        icon,
        size: size * 0.5,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

/// A small pill label, e.g. category filter or plan-limit tag.
class AppPillChip extends StatelessWidget {
  const AppPillChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedFill = theme.colorScheme.secondary;
    final selectedOn = theme.colorScheme.onSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? selectedFill : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(
            color: selected
                ? selectedFill
                : (theme.dividerTheme.color ?? AppColors.borderLight),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: selected ? selectedOn : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
