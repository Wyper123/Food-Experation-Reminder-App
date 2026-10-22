import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/constants/storage_locations.dart';
import 'package:food_expiration_reminder/core/utils/date_formatter.dart';
import 'package:food_expiration_reminder/core/utils/status_color_helper.dart';
import 'package:food_expiration_reminder/core/widgets/status_badge.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';

class FoodCard extends StatelessWidget {
  const FoodCard({super.key, required this.item, this.onTap});

  final FoodItemModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = item.effectiveStatus;
    final fg = StatusColorHelper.foreground(context, status);
    final muted = AppTextStyles.caption.copyWith(color: cs.onSurfaceVariant);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: StatusColorHelper.background(context, status),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.storage.icon, color: fg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppTextStyles.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.storage.label} · ${item.quantity} ${item.unit}',
                      style: muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Expires ${DateFormatter.compact(item.expirationDate)}',
                      style: muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(status: status),
                  if (item.isActive) ...[
                    const SizedBox(height: 8),
                    Text(
                      DateFormatter.daysShort(item.daysRemaining),
                      style: AppTextStyles.caption.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
