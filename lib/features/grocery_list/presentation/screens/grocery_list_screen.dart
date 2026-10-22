import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_colors.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/widgets/custom_button.dart';
import 'package:food_expiration_reminder/core/widgets/empty_state_widget.dart';
import 'package:food_expiration_reminder/core/widgets/skeleton_loader.dart';
import 'package:food_expiration_reminder/data/models/grocery_item_model.dart';
import 'package:food_expiration_reminder/features/grocery_list/presentation/controllers/grocery_controller.dart';
import 'package:food_expiration_reminder/features/grocery_list/presentation/screens/move_to_inventory_screen.dart';
import 'package:food_expiration_reminder/features/grocery_list/presentation/widgets/add_grocery_dialog.dart';
import 'package:food_expiration_reminder/features/grocery_list/presentation/widgets/grocery_item_tile.dart';
import 'package:provider/provider.dart';

class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({super.key});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  GroceryController get _grocery => context.read<GroceryController>();

  Future<void> _add() async {
    final item = await showAddGroceryDialog(context);
    if (item != null) await _grocery.add(item);
  }

  Future<void> _edit(GroceryItemModel item) async {
    final updated = await showAddGroceryDialog(context, item: item);
    if (updated != null) await _grocery.update(updated);
  }

  Future<void> _moveToInventory() async {
    final messenger = ScaffoldMessenger.of(context);
    final moved = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => MoveToInventoryScreen(items: _grocery.checked),
      ),
    );
    if (moved == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          moved == 1
              ? '1 item added to your inventory'
              : '$moved items added to your inventory',
        ),
      ),
    );
  }

  Color _priorityColor(GroceryPriority p) => switch (p) {
        GroceryPriority.high => AppColors.crimson,
        GroceryPriority.medium => AppColors.amber,
        GroceryPriority.low => AppColors.emerald,
      };

  @override
  Widget build(BuildContext context) {
    final grocery = context.watch<GroceryController>();
    final isLoading = grocery.isLoading;
    final items = grocery.items;
    final checkedCount = grocery.checked.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grocery list'),
        actions: [
          if (!isLoading && checkedCount > 0)
            TextButton(
              onPressed: () => grocery.setAllChecked(false),
              child: const Text('Uncheck all'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: checkedCount > 0
          ? null
          : FloatingActionButton(
              heroTag: 'grocery-fab',
              tooltip: 'Add item',
              onPressed: isLoading ? null : _add,
              child: const Icon(Icons.add_rounded),
            ),
      bottomNavigationBar: isLoading || checkedCount == 0
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
                  label: 'Move $checkedCount checked to inventory',
                  icon: Icons.move_down_rounded,
                  onPressed: _moveToInventory,
                ),
              ),
            ),
      body: RefreshIndicator(
        onRefresh: grocery.refresh,
        child: isLoading
            ? ListView(
                padding: const EdgeInsets.all(AppConstants.pagePadding),
                children: [
                  SkeletonLoader(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var s = 0; s < 3; s++) ...[
                          const SkeletonBox(width: 120, height: 14, radius: 6),
                          const SizedBox(height: 12),
                          for (var i = 0; i < 2; i++)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: GroceryItemTileSkeleton(),
                            ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ],
              )
            : items.isEmpty
                ? ListView(
                    children: [
                      EmptyStateWidget(
                        icon: Icons.shopping_basket_outlined,
                        title: 'List is empty',
                        message: 'Add items you need to buy next trip.',
                        actionLabel: 'Add item',
                        onAction: _add,
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.pagePadding,
                      4,
                      AppConstants.pagePadding,
                      96,
                    ),
                    children: [
                      for (final p in GroceryPriority.values)
                        ..._buildSection(items, p),
                    ],
                  ),
      ),
    );
  }

  List<Widget> _buildSection(
    List<GroceryItemModel> all,
    GroceryPriority p,
  ) {
    final items = all.where((e) => e.priority == p).toList();
    if (items.isEmpty) return const [];
    final cs = Theme.of(context).colorScheme;
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 10),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.onTintOf(context, _priorityColor(p)),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text('${p.label} priority', style: AppTextStyles.title),
            const SizedBox(width: 8),
            Text(
              '${items.length}',
              style: AppTextStyles.caption.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GroceryItemTile(
            item: item,
            onChanged: (v) => _grocery.setChecked(item.id, v),
            onEdit: () => _edit(item),
            onDelete: () => _grocery.delete(item.id),
          ),
        ),
    ];
  }
}
