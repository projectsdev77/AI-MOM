import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Plus Jakarta Sans type scale for the AI MOM light-system redesign.
///
/// Kept separate from [AppTypography] (Manrope) rather than replacing it —
/// screens migrate to this scale one at a time, so both fonts coexist
/// until every screen has moved over.
class MomText {
  MomText._();

  static TextStyle _jakarta(double size, FontWeight weight, Color color, {double? letterSpacing, double? height}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Screen title / Home greeting — 26/800, -0.02em.
  static TextStyle screenTitle(Color color) => _jakarta(26, FontWeight.w800, color, letterSpacing: -0.52, height: 1.15);

  /// Card title — 17/700.
  static TextStyle cardTitle(Color color) => _jakarta(17, FontWeight.w700, color);

  /// Section header — 15/700.
  static TextStyle section(Color color) => _jakarta(15, FontWeight.w700, color);

  /// Option/settings row label — 15/600, 700 when selected.
  static TextStyle rowLabel(Color color, {bool selected = false}) =>
      _jakarta(15, selected ? FontWeight.w700 : FontWeight.w600, color);

  /// Option row sub-line — 11.5/500.
  static TextStyle rowSub(Color color) => _jakarta(11.5, FontWeight.w500, color);

  /// Task title — 14.5/700.
  static TextStyle taskTitle(Color color) => _jakarta(14.5, FontWeight.w700, color);

  /// Task meta label — 10/700 uppercase, 0.08em (apply .toUpperCase() to text).
  static TextStyle taskMetaLabel(Color color) => _jakarta(10, FontWeight.w700, color, letterSpacing: 0.8);

  /// Mom message-card body — 14/600, line-height 1.45.
  static TextStyle momMessage(Color color) => _jakarta(14, FontWeight.w600, color, height: 1.45);

  /// Mood/eyebrow label above a Mom message — 11.5/700 uppercase, 0.06em.
  static TextStyle eyebrow(Color color) => _jakarta(11.5, FontWeight.w700, color, letterSpacing: 0.69);

  /// Chip label — 14/600, 700 when selected.
  static TextStyle chipLabel(Color color, {bool selected = false}) =>
      _jakarta(14, selected ? FontWeight.w700 : FontWeight.w600, color);

  /// Body / subtitle copy — 13/500.
  static TextStyle body(Color color) => _jakarta(13, FontWeight.w500, color);

  /// Meta / stat caption — 11-12/500 (default 11.5).
  static TextStyle meta(Color color, {double size = 11.5}) => _jakarta(size, FontWeight.w500, color);

  /// Stat card value — 19/800.
  static TextStyle statValue(Color color) => _jakarta(19, FontWeight.w800, color);

  /// Nav label — 10.5/600, 700 when active.
  static TextStyle navLabel(Color color, {bool active = false}) =>
      _jakarta(10.5, active ? FontWeight.w700 : FontWeight.w600, color);

  /// Primary/secondary button label — 15/700.
  static TextStyle button(Color color) => _jakarta(15, FontWeight.w700, color);

  /// Small tappable control / link label — 11.5-12/700 (e.g. "Upgrade",
  /// "Edit budget", "See report").
  static TextStyle control(Color color, {double size = 11.5}) => _jakarta(size, FontWeight.w700, color);

  /// Field placeholder / counter text — 14-15/500.
  static TextStyle placeholder(Color color, {double size = 14}) => _jakarta(size, FontWeight.w500, color);
}
