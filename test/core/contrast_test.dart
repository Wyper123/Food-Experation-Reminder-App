import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiration_reminder/core/constants/app_colors.dart';

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const accents = {
    'emerald': AppColors.emerald,
    'amber': AppColors.amber,
    'crimson': AppColors.crimson,
    'blue': AppColors.blue,
    'purple': AppColors.purple,
    'inkMuted': AppColors.inkMuted,
  };
  const grounds = {
    Brightness.light: [AppColors.background, AppColors.surface],
    Brightness.dark: [AppColors.darkBackground, AppColors.darkSurface],
  };
  // Every tint strength the UI draws coloured text or icons on.
  const tints = [0.0, 0.11, 0.13, 0.14, 0.18, 0.22];

  for (final MapEntry(key: name, value: accent) in accents.entries) {
    for (final MapEntry(key: brightness, value: backgrounds)
        in grounds.entries) {
      test('$name text is AA-legible on its tints (${brightness.name})', () {
        final fg = AppColors.onTint(accent, brightness);
        for (final ground in backgrounds) {
          for (final a in tints) {
            final bg = Color.alphaBlend(accent.withValues(alpha: a), ground);
            expect(
              contrast(fg, bg),
              greaterThanOrEqualTo(4.5),
              reason: 'tint $a on $ground',
            );
          }
        }
      });
    }
  }

  test('white text is legible on the brand gradient', () {
    for (final stop in AppColors.brandGradient) {
      expect(contrast(Colors.white, stop), greaterThanOrEqualTo(4.5));
    }
  });

  test('dark-mode cards stand out from the background', () {
    expect(
      contrast(AppColors.darkSurface, AppColors.darkBackground),
      greaterThan(1.15),
    );
  });
}
