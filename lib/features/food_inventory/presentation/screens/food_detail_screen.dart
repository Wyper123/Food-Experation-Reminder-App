import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/constants/storage_locations.dart';
import 'package:food_expiration_reminder/core/utils/date_formatter.dart';
import 'package:food_expiration_reminder/core/utils/status_color_helper.dart';
import 'package:food_expiration_reminder/core/widgets/custom_button.dart';
import 'package:food_expiration_reminder/core/widgets/skeleton_loader.dart';
import 'package:food_expiration_reminder/core/widgets/status_badge.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/controllers/inventory_controller.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/screens/add_edit_food_screen.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/widgets/food_status_dialog.dart';
import 'package:provider/provider.dart';

class FoodDetailScreen extends StatelessWidget {
  const FoodDetailScreen({super.key, required this.itemId});

  final String itemId;

  Future<void> _changeStatus(BuildContext context, FoodItemModel item) async {
    final inventory = context.read<InventoryController>();
    final picked = await showFoodStatusDialog(context, current: item.status);
    if (picked != null) await inventory.setStatus(item.id, picked);
  }

  void _confirmDelete(BuildContext context, FoodItemModel item) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete ${item.name}?', style: AppTextStyles.headline),
              const SizedBox(height: 8),
              Text(
                'This removes the record entirely. To keep history, mark it '
                'as consumed or discarded instead.',
                style: AppTextStyles.body.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              CustomButton(
                label: 'Delete item',
                icon: Icons.delete_outline_rounded,
                variant: CustomButtonVariant.danger,
                onPressed: () async {
                  final inventory = context.read<InventoryController>();
                  final navigator = Navigator.of(context);
                  Navigator.of(ctx).pop();
                  navigator.pop();
                  await inventory.delete(item.id);
                },
              ),
              const SizedBox(height: 8),
              CustomButton(
                label: 'Cancel',
                variant: CustomButtonVariant.text,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryController>();
    final item = inventory.byId(itemId);
    final isLoading = inventory.isLoading || item == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food details'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: isLoading
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddEditFoodScreen(item: item),
                      ),
                    ),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: isLoading ? null : () => _confirmDelete(context, item),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: isLoading ? const _DetailSkeleton() : _buildContent(context, item),
      bottomNavigationBar: isLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.pagePadding,
                  8,
                  AppConstants.pagePadding,
                  12,
                ),
                child: CustomButton(
                  label: 'Update status',
                  icon: Icons.published_with_changes_rounded,
                  onPressed: () => _changeStatus(context, item),
                ),
              ),
            ),
    );
  }

  Widget _buildContent(BuildContext context, FoodItemModel item) {
    final cs = Theme.of(context).colorScheme;
    final status = item.effectiveStatus;
    final fg = StatusColorHelper.foreground(context, status);

    return ListView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      children: [
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: StatusColorHelper.background(context, status),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(item.storage.icon, color: fg, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: AppTextStyles.headline),
                  const SizedBox(height: 4),
                  Text(
                    [item.category, if (item.brand != null) item.brand!]
                        .join(' · '),
                    style: AppTextStyles.body.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StatusBadge(status: status),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (item.isActive)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: StatusColorHelper.background(context, status),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Row(
              children: [
                Icon(StatusColorHelper.icon(status), color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormatter.daysLabel(item.daysRemaining),
                    style: AppTextStyles.title.copyWith(color: fg),
                  ),
                ),
                Text(
                  DateFormatter.short(item.expirationDate),
                  style: AppTextStyles.subtitle.copyWith(color: fg),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.scale_outlined,
                label: 'Quantity',
                value: '${item.quantity} ${item.unit}',
              ),
              const Divider(indent: 56),
              _InfoRow(
                icon: item.storage.icon,
                label: 'Storage',
                value: item.storage.fullLabel,
              ),
              const Divider(indent: 56),
              _InfoRow(
                icon: Icons.shopping_cart_outlined,
                label: 'Purchased',
                value: DateFormatter.short(item.purchaseDate),
              ),
              const Divider(indent: 56),
              _InfoRow(
                icon: Icons.event_busy_outlined,
                label: 'Expires',
                value: DateFormatter.short(item.expirationDate),
              ),
              const Divider(indent: 56),
              _InfoRow(
                icon: Icons.lock_open_rounded,
                label: 'Opened',
                value: item.openingDate == null
                    ? 'Sealed'
                    : DateFormatter.short(item.openingDate!),
              ),
              const Divider(indent: 56),
              _InfoRow(
                icon: Icons.add_circle_outline_rounded,
                label: 'Added',
                value: DateFormatter.relativeTime(item.addedAt),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: cs.onSurfaceVariant),
          const SizedBox(width: 18),
          Text(
            label,
            style: AppTextStyles.body.copyWith(color: cs.onSurfaceVariant),
          ),
          const Spacer(),
          Text(value, style: AppTextStyles.subtitle),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppConstants.pagePadding),
        children: [
          const Row(
            children: [
              SkeletonBox(width: 64, height: 64, radius: 20),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 160, height: 20, radius: 6),
                  SizedBox(height: 8),
                  SkeletonBox(width: 110, height: 12, radius: 6),
                  SizedBox(height: 10),
                  SkeletonBox(width: 80, height: 24, radius: 12),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SkeletonBox(height: 56, radius: AppConstants.radiusMd),
          const SizedBox(height: 16),
          for (var i = 0; i < 6; i++)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  SkeletonBox(width: 22, height: 22, radius: 6),
                  SizedBox(width: 18),
                  SkeletonBox(width: 80, height: 12, radius: 6),
                  Spacer(),
                  SkeletonBox(width: 96, height: 12, radius: 6),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
