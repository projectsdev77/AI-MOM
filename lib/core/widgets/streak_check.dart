import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

/// The completion control for a task/habit row — an outlined circle that
/// fills solid orange with a check once tapped. This is the app's single
/// "done" affordance, reused everywhere (dashboard, task list).
class StreakCheck extends StatelessWidget {
  const StreakCheck({
    super.key,
    required this.done,
    required this.onTap,
    this.size = 28,
  });

  final bool done;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerTheme.color ?? AppColors.borderLight;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? AppColors.accent : Colors.transparent,
          border: Border.all(
            color: done ? AppColors.accent : border,
            width: 1.5,
          ),
        ),
        child: done
            ? Icon(LucideIcons.check, size: size * 0.6, color: Colors.white)
            : null,
      ),
    );
  }
}
