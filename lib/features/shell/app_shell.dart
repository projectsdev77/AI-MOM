import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/app_state_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_mood.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/widgets/mom_avatar.dart';

/// Bottom-nav shell wrapping the 5 main tabs. Uses a StatefulShellRoute so
/// each tab keeps its own scroll/navigation state when switching back.
///
/// The center tab is Mom (was labelled "Chat") — same destination, same
/// branch index, just rendered as a raised avatar circle instead of an icon.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (icon: LucideIcons.house, label: 'Home'),
    (icon: LucideIcons.listChecks, label: 'Tasks'),
    (icon: null, label: 'Mom'),
    (icon: LucideIcons.chartNoAxesColumn, label: 'Track'),
    (icon: LucideIcons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    final momAvatar = ref.watch(effectiveMomAvatarProvider);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: mom.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.momRadiusNav)),
          boxShadow: MomElevation.nav,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
            child: SizedBox(
              height: 42,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: i == 2
                          ? _MomNavItem(
                              style: momAvatar,
                              selected: navigationShell.currentIndex == i,
                              onTap: () => navigationShell.goBranch(
                                i,
                                initialLocation: i == navigationShell.currentIndex,
                              ),
                            )
                          : _NavItem(
                              icon: _tabs[i].icon!,
                              label: _tabs[i].label,
                              selected: navigationShell.currentIndex == i,
                              onTap: () => navigationShell.goBranch(
                                i,
                                initialLocation: i == navigationShell.currentIndex,
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final color = selected ? mom.espresso : mom.navInactive;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(height: 4),
          Text(label, style: MomText.navLabel(color, active: selected)),
        ],
      ),
    );
  }
}

/// The center "Mom" tab — raised 56px peach circle holding Mom's avatar,
/// replacing the old plain chat-bubble icon.
class _MomNavItem extends StatelessWidget {
  const _MomNavItem({required this.style, required this.selected, required this.onTap});

  final MomAvatarStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return InkWell(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Sits in the normal nav-bar row, aligned like the other tabs'
          // labels — this is what actually gives the Stack its 42px height.
          Text('Mom', style: MomText.navLabel(selected ? mom.espresso : mom.navInactive, active: selected)),
          // The 56px avatar circle is explicitly centered and raised above
          // the bar via Positioned (real layout), not a paint-only
          // Transform — so it's never off-center and never overflows.
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mom.promoPeach,
                  border: Border.all(color: mom.surface, width: 3),
                  boxShadow: MomElevation.fab,
                ),
                child: MomAvatar(style: style, expression: MomExpression.normal, showMoodBadge: false, size: 38),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 56px espresso FAB used on Home/Tasks/Financial for the primary
/// create action. Screens position it themselves via
/// `Scaffold.floatingActionButton`.
class MomFab extends StatelessWidget {
  const MomFab({super.key, required this.onPressed, this.tooltip});

  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: MomElevation.fab),
      child: FloatingActionButton(
        // Home/Tasks/Financial all stay mounted at once under the bottom
        // nav's StatefulShellRoute, so their FABs would otherwise share
        // Flutter's implicit default hero tag and collide on any route
        // transition ("multiple heroes share the same tag"). This FAB never
        // needs to hero-morph into another screen's FAB, so just opt out.
        heroTag: null,
        onPressed: onPressed,
        tooltip: tooltip,
        backgroundColor: mom.espresso,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
        child: const Icon(LucideIcons.plus, size: 24),
      ),
    );
  }
}
