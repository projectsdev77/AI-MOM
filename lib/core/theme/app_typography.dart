import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale for AI Mom.
///
/// Manrope only — a humanist geometric sans, deliberately not Inter or
/// Poppins. Hierarchy comes from weight + size jumps, never color or
/// letter-spacing tricks, and never gradient text or all-caps.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(Color primary, Color secondary) {
    final base = GoogleFonts.manropeTextTheme();
    return base.copyWith(
      // Greeting / screen headline — "Morning, Alex"
      headlineLarge: GoogleFonts.manrope(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.2,
        color: primary,
      ),
      // Subheadline / date line under the greeting.
      titleSmall: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      // Card / section titles.
      titleLarge: GoogleFonts.manrope(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      // Body / list item titles.
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      // Metadata — streaks, time, labels.
      bodySmall: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      // Button text.
      labelLarge: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}
