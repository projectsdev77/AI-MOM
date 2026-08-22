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
}
