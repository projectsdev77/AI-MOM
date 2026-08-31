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
    void goToMom() => navigationShell.goBranch(2, initialLocation: 2 == navigationShell.currentIndex);
    // Scaffold paints bottomNavigationBar *after* (on top of) body, so
    // anything painted from body that dips into the bar's rectangle via
    // overflow gets hidden behind the bar's own opaque background —
    // and anything that stays within body's own bounds to avoid that
    // can't be hit-tested past those bounds either (Flutter hit-tests
    // an ancestor's own reported size, not wherever a Positioned/
    // Clip.none child merely paints outside it). So the raised circle
    // can't be *painted* from body, and can't be reliably *tapped* from
    // inside the bar's height-42 Row. The only way to have both is to
    // give bottomNavigationBar itself a real box tall enough to contain
    // the whole circle — no overflow anywhere, so ordinary bounds-based
    // hit-testing just works.
    const momHeadroom = 40.0;
    final safeAreaBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SizedBox(
        height: momHeadroom + safeAreaBottom + 12 + 42 + 22,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
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
                                  // Mom's circle is painted (and made
                                  // tappable) above, in this same Stack, not
                                  // here — this just reserves equal width so
                                  // the other 4 tabs stay evenly spaced.
                                  ? const SizedBox.shrink()
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
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: safeAreaBottom + 22,
              child: Center(
                child: _MomNavItem(
                  style: momAvatar,
                  selected: navigationShell.currentIndex == 2,
                  onTap: goToMom,
                ),
              ),
            ),
          ],
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
/// replacing the old plain chat-bubble icon. The circle Container is the
/// tap target itself (via InkWell, so it also gets the usual ripple),
/// rather than a separately positioned invisible hit box guessing at
/// where the circle happens to be painted.
class _MomNavItem extends StatelessWidget {
  const _MomNavItem({required this.style, required this.selected, required this.onTap});

  final MomAvatarStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(3),
              alignment: Alignment.center,
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
        const SizedBox(height: 2),
        GestureDetector(
          onTap: onTap,
          child: Text('Mom', style: MomText.navLabel(selected ? mom.espresso : mom.navInactive, active: selected)),
        ),
      ],
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
