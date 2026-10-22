import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/constants/storage_locations.dart';
import 'package:food_expiration_reminder/core/utils/date_formatter.dart';
import 'package:food_expiration_reminder/core/utils/status_color_helper.dart';
import 'package:food_expiration_reminder/core/widgets/status_badge.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';

/// "Use First" urgency card: name, storage, days badge and quick actions.
class ExpirationSummaryCard extends StatelessWidget {
  const ExpirationSummaryCard({
    super.key,
    required this.item,
    this.onTap,
    this.onConsumed,
    this.onDiscarded,
    this.onAddToGrocery,
  });

  final FoodItemModel item;
  final VoidCallback? onTap;
  final VoidCallback? onConsumed;
  final VoidCallback? onDiscarded;
  final VoidCallback? onAddToGrocery;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = item.effectiveStatus;
    final accent = StatusColorHelper.color(status);
    final fg = StatusColorHelper.foreground(context, status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: StatusColorHelper.background(context, status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.storage.icon, color: fg, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.name,
                              style: AppTextStyles.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${item.storage.label} · ${DateFormatter.daysLabel(item.daysRemaining)}',
                              style: AppTextStyles.caption.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      DaysBadge(days: item.daysRemaining),
                      PopupMenuButton<VoidCallback?>(
                        tooltip: 'Quick actions',
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                        onSelected: (action) => action?.call(),
                        itemBuilder: (_) => [
                          for (final s in [
                            FoodStatus.consumed,
                            FoodStatus.discarded,
                          ])
                            PopupMenuItem(
                              value: s == FoodStatus.consumed
                                  ? onConsumed
                                  : onDiscarded,
                              child: Row(
                                children: [
                                  Icon(
                                    StatusColorHelper.icon(s),
                                    size: 20,
                                    color: StatusColorHelper.foreground(
                                      context,
                                      s,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                      'Mark ${StatusColorHelper.label(s).toLowerCase()}'),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: onAddToGrocery,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 20,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 10),
                                const Text('Add to grocery list'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
