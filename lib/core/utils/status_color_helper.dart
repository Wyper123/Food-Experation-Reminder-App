import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_colors.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';

/// Maps FoodStatus (Available, Use Soon, Expired, Consumed, Discarded)
/// to labels, icons and theme-aware colours.
class StatusColorHelper {
  StatusColorHelper._();

  static FoodStatus fromDays(int days) {
    if (days < 0) return FoodStatus.expired;
    if (days <= AppConstants.useSoonThresholdDays) return FoodStatus.useSoon;
    return FoodStatus.available;
  }

  static Color color(FoodStatus s) => switch (s) {
        FoodStatus.available => AppColors.emerald,
        FoodStatus.useSoon => AppColors.amber,
        FoodStatus.expired => AppColors.crimson,
        FoodStatus.consumed => AppColors.blue,
        FoodStatus.discarded => AppColors.inkMuted,
      };

  /// Text/icon colour with enough contrast on top of [background].
  static Color foreground(BuildContext context, FoodStatus s) =>
      AppColors.onTintOf(context, color(s));

  static Color background(BuildContext context, FoodStatus s) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return color(s).withValues(alpha: dark ? 0.22 : 0.13);
  }

  static String label(FoodStatus s) => switch (s) {
        FoodStatus.available => 'Available',
        FoodStatus.useSoon => 'Use Soon',
        FoodStatus.expired => 'Expired',
        FoodStatus.consumed => 'Consumed',
        FoodStatus.discarded => 'Discarded',
      };

  static IconData icon(FoodStatus s) => switch (s) {
        FoodStatus.available => Icons.check_circle_outline_rounded,
        FoodStatus.useSoon => Icons.schedule_rounded,
        FoodStatus.expired => Icons.error_outline_rounded,
        FoodStatus.consumed => Icons.task_alt_rounded,
        FoodStatus.discarded => Icons.delete_outline_rounded,
      };
}
