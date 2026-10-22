import 'package:flutter/material.dart';

/// Central colour palette.
/// Fresh Emerald / Caution Amber / Alert Crimson + crisp neutral backgrounds.
///
/// Accent colours are for fills and tints. Text and icons drawn in an accent
/// colour must go through [onTint], which returns a shade that stays legible
/// (WCAG AA, at least 4.5:1) on that accent's tint in the current theme.
class AppColors {
  AppColors._();

  // Brand & status accents (fills, tints, accent bars)
  static const Color emerald = Color(0xFF12A072);
  static const Color amber = Color(0xFFF2A100);
  static const Color crimson = Color(0xFFD7263D);
  static const Color blue = Color(0xFF2F6FDE);
  static const Color purple = Color(0xFF8E5BD8);

  /// Light-theme primary; also behind white text on brand gradients.
  static const Color emeraldDark = Color(0xFF0A7A55);
  static const Color emeraldDeep = Color(0xFF07573D);

  /// Header cards and logo tiles. White text stays above 5:1 on both stops.
  static const List<Color> brandGradient = [emeraldDark, emeraldDeep];

  // Neutrals
  static const Color background = Color(0xFFF6F7F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1A2420);
  static const Color inkMuted = Color(0xFF65726B);

  // Dark mode neutrals: cards sit visibly above the background.
  static const Color darkBackground = Color(0xFF0E1311);
  static const Color darkSurface = Color(0xFF1C2622);

  // Shimmer
  static const Color shimmerBase = Color(0xFFE6EAE5);
  static const Color shimmerHighlight = Color(0xFFF5F7F4);
  static const Color shimmerBaseDark = Color(0xFF26302B);
  static const Color shimmerHighlightDark = Color(0xFF34403A);

  // Legible text/icon shades per accent: deeper on light, lighter on dark.
  static final Map<Color, (Color, Color)> _onTint = {
    emerald: (Color(0xFF076A4A), Color(0xFF4ED6A4)),
    amber: (Color(0xFF7A4F00), Color(0xFFF7B733)),
    crimson: (Color(0xFFA3182B), Color(0xFFFF8A96)),
    blue: (Color(0xFF1D4FA8), Color(0xFF8DB2FF)),
    purple: (Color(0xFF6A3BB5), Color(0xFFC3A6F5)),
    inkMuted: (Color(0xFF4F5B55), Color(0xFFA9B5AE)),
  };

  /// Text/icon colour for [accent] on a tint of it (or on a plain surface).
  static Color onTint(Color accent, Brightness brightness) {
    final pair = _onTint[accent];
    if (pair == null) return accent;
    return brightness == Brightness.dark ? pair.$2 : pair.$1;
  }

  /// [onTint] for the theme of [context].
  static Color onTintOf(BuildContext context, Color accent) =>
      onTint(accent, Theme.of(context).brightness);
}
