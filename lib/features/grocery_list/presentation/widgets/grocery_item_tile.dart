import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/widgets/skeleton_loader.dart';
import 'package:food_expiration_reminder/data/models/grocery_item_model.dart';

class GroceryItemTile extends StatelessWidget {
  const GroceryItemTile({
    super.key,
    required this.item,
    required this.onChanged,
    this.onEdit,
    this.onDelete,
  });

  final GroceryItemModel item;
  final ValueChanged<bool> onChanged;

  /// Tapping the row edits; the checkbox ticks. Without [onEdit], tapping
  /// the row ticks too.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final checked = item.isChecked;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit ?? () => onChanged(!checked),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: (v) => onChanged(v ?? false),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppTextStyles.subtitle.copyWith(
                        decoration: checked ? TextDecoration.lineThrough : null,
                        color: checked ? cs.onSurfaceVariant : cs.onSurface,
                      ),
                    ),
                    Text(
                      [item.quantity, ?item.category].join(' · '),
                      style: AppTextStyles.caption.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Remove',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder mirroring [GroceryItemTile]. Wrap in [SkeletonLoader].
class GroceryItemTileSkeleton extends StatelessWidget {
  const GroceryItemTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          SkeletonBox(width: 20, height: 20, radius: 6),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 130, height: 13, radius: 6),
                SizedBox(height: 7),
                SkeletonBox(width: 60, height: 10, radius: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
