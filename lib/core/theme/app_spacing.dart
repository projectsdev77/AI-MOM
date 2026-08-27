/// Spacing and radius tokens.
///
/// Radii are deliberately *not* uniform — pills for buttons/chips, a
/// generous card radius, a tighter radius for small list rows — so
/// rounding reads as a decision, not a global default.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const double radiusRow = 14;
  static const double radiusCard = 22;
  static const double radiusSheet = 28;
  static const double radiusPill = 999;

  // ---------------------------------------------------------------------
  // AI MOM light system — new radius/space tokens. Additive alongside the
  // set above; screens migrate to these one at a time.
  // ---------------------------------------------------------------------

  static const double momBase = 4;
  static const double momGutter = 20;
  static const double momRowGap = 10;
  static const double momSectionGap = 20;

  static const double momRadiusTile = 12;
  static const double momRadiusCard = 18;
  static const double momRadiusPanelSm = 20;
  static const double momRadiusPanel = 24;
  static const double momRadiusSheet = 32;
  static const double momRadiusNav = 28;
  static const double momRadiusPill = 999;

  /// Minimum tappable hit target on every AI MOM screen.
  static const double momMinHitTarget = 44;
}
