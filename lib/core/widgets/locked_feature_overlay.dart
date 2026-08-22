import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Wraps a Full-tier feature for Basic users: content stays visible
/// underneath (dimmed, non-interactive) with an "Upgrade to unlock" card
/// on top — same dashboard for everyone, per plan, rather than hiding
/// the feature outright.
class LockedFeatureOverlay extends StatelessWidget {
  const LockedFeatureOverlay({
    super.key,
    required this.child,
    required this.featureName,
    this.onUpgradeTap,
  });

  final Widget child;
  final String featureName;
  final VoidCallback? onUpgradeTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        IgnorePointer(
          child: Opacity(opacity: 0.35, child: child),
        ),
        Positioned.fill(
          child: Center(
            child: GestureDetector(
              onTap: onUpgradeTap,
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.lg),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  border: Border.all(color: AppColors.accent, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.lock, size: 16, color: AppColors.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Unlock $featureName with Full Mom',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
