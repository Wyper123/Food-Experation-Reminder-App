import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/utils/date_formatter.dart';
import 'package:food_expiration_reminder/core/utils/status_color_helper.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';

/// Pill badge: Available / Use Soon / Expired / Consumed / Discarded.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final FoodStatus status;

  @override
  Widget build(BuildContext context) {
    final fg = StatusColorHelper.foreground(context, status);
    final bg = StatusColorHelper.background(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            StatusColorHelper.label(status),
            style: AppTextStyles.label.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// Badge showing days remaining, coloured by urgency.
class DaysBadge extends StatelessWidget {
  const DaysBadge({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final status = StatusColorHelper.fromDays(days);
    final fg = StatusColorHelper.foreground(context, status);
    final bg = StatusColorHelper.background(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        DateFormatter.daysShort(days),
        style: AppTextStyles.label.copyWith(color: fg),
      ),
    );
  }
}
