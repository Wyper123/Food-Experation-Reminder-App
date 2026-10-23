import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_colors.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/widgets/empty_state_widget.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:food_expiration_reminder/data/models/grocery_item_model.dart';
import 'package:food_expiration_reminder/features/auth/presentation/controllers/session_controller.dart';
import 'package:food_expiration_reminder/features/dashboard/presentation/widgets/dashboard_skeleton.dart';
import 'package:food_expiration_reminder/features/dashboard/presentation/widgets/expiration_summary_card.dart';
import 'package:food_expiration_reminder/features/dashboard/presentation/widgets/quick_stats_banner.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/controllers/inventory_controller.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/screens/add_edit_food_screen.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/screens/food_detail_screen.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/screens/inventory_list_screen.dart';
import 'package:food_expiration_reminder/features/grocery_list/presentation/controllers/grocery_controller.dart';
import 'package:food_expiration_reminder/features/household/presentation/controllers/household_controller.dart';
import 'package:food_expiration_reminder/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:food_expiration_reminder/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    this.onViewInventory,
    this.onViewGroceries,
  });

  /// Switches the shell to the Inventory tab with the given filter.
  final ValueChanged<InventoryStatusFilter>? onViewInventory;

  /// Switches the shell to the Groceries tab.
  final VoidCallback? onViewGroceries;

  Future<void> _setStatus(
    BuildContext context,
    FoodItemModel item,
    FoodStatus status,
  ) async {
    final inventory = context.read<InventoryController>();
    final messenger = ScaffoldMessenger.of(context);
    await inventory.setStatus(item.id, status);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${item.name} marked ${status == FoodStatus.consumed ? 'consumed' : 'discarded'}',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => inventory.setStatus(item.id, item.status),
          ),
        ),
      );
  }

  Future<void> _addToGrocery(BuildContext context, FoodItemModel item) async {
    final grocery = context.read<GroceryController>();
    final messenger = ScaffoldMessenger.of(context);
    final name = item.name.trim();
    final alreadyListed = grocery.items.any(
      (g) => !g.isChecked && g.name.toLowerCase() == name.toLowerCase(),
    );
    if (!alreadyListed) {
      await grocery.add(
        GroceryItemModel(
          id: const Uuid().v4(),
          name: name,
          quantity: '${item.quantity} ${item.unit}',
          // Use-first items are about to run out, so rebuy them first.
          priority: GroceryPriority.high,
          category: item.category,
        ),
      );
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            alreadyListed
                ? '$name is already on your grocery list'
                : '$name added to your grocery list',
          ),
          action: onViewGroceries == null
              ? null
              : SnackBarAction(label: 'View', onPressed: onViewGroceries!),
        ),
      );
  }

  Future<void> _refreshAll(BuildContext context) => Future.wait([
        context.read<InventoryController>().refresh(),
        context.read<NotificationsController>().refresh(),
        context.read<HouseholdController>().refresh(),
      ]);

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inventory = context.watch<InventoryController>();
    final user = context.watch<SessionController>().user;
    final household = context.watch<HouseholdController>().household;
    final unread = context.watch<NotificationsController>().unreadCount;

    final useFirst = inventory.active
        .where((e) => e.daysRemaining <= AppConstants.useSoonThresholdDays)
        .toList()
      ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pantry overview'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              backgroundColor: AppColors.crimson,
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // Hidden on an empty kitchen: the empty state has its own button,
      // which this one would cover.
      floatingActionButton: !inventory.isLoading && inventory.items.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'dashboard-fab',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddEditFoodScreen()),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add food'),
            ),
      body: RefreshIndicator(
        onRefresh: () => _refreshAll(context),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            4,
            AppConstants.pagePadding,
            96,
          ),
          children: inventory.error != null && inventory.items.isEmpty
              ? [
                  EmptyStateWidget(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load your kitchen',
                    message: 'Pull down or tap below to try again.',
                    actionLabel: 'Try again',
                    onAction: () => _refreshAll(context),
                  ),
                ]
              : inventory.isLoading || user == null
                  ? const [DashboardSkeleton()]
                  : [
                      _WelcomeCard(
                        greeting: _greeting,
                        name: user.name.split(' ').first,
                        householdName: household?.name ?? 'Personal kitchen',
                        memberCount: household?.members.length ?? 1,
                      ),
                      const SizedBox(height: 16),
                      QuickStatsBanner(
                        expiringSoon:
                            inventory.countByStatus(FoodStatus.useSoon),
                        expired: inventory.countByStatus(FoodStatus.expired),
                        totalStored: inventory.active.length,
                        onExpiringSoonTap: () => onViewInventory
                            ?.call(InventoryStatusFilter.useSoon),
                        onExpiredTap: () => onViewInventory
                            ?.call(InventoryStatusFilter.expired),
                        onTotalTap: () =>
                            onViewInventory?.call(InventoryStatusFilter.all),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Use first',
                              style: AppTextStyles.headline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () => onViewInventory
                                ?.call(InventoryStatusFilter.all),
                            child: const Text('See all'),
                          ),
                        ],
                      ),
                      Text(
                        'Expired or expiring within ${AppConstants.useSoonThresholdDays} days',
                        style: AppTextStyles.caption.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (inventory.items.isEmpty)
                        EmptyStateWidget(
                          icon: Icons.kitchen_outlined,
                          title: 'Your kitchen is empty',
                          message:
                              'Add the food you have and we will tell you what '
                              'to use first.',
                          actionLabel: 'Add your first item',
                          onAction: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AddEditFoodScreen(),
                            ),
                          ),
                        )
                      else if (useFirst.isEmpty)
                        const EmptyStateWidget(
                          icon: Icons.celebration_outlined,
                          title: 'Nothing urgent',
                          message: 'Everything in your kitchen is still fresh.',
                        )
                      else
                        for (final item in useFirst)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ExpirationSummaryCard(
                              item: item,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FoodDetailScreen(itemId: item.id),
                                ),
                              ),
                              onConsumed: () => _setStatus(
                                  context, item, FoodStatus.consumed),
                              onDiscarded: () => _setStatus(
                                  context, item, FoodStatus.discarded),
                              onAddToGrocery: () =>
                                  _addToGrocery(context, item),
                            ),
                          ),
                    ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.greeting,
    required this.name,
    required this.householdName,
    required this.memberCount,
  });

  final String greeting;
  final String name;
  final String householdName;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: AppColors.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: AppTextStyles.headline.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.home_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$householdName · $memberCount '
                          '${memberCount == 1 ? 'member' : 'members'}',
                          style: AppTextStyles.label.copyWith(
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 34),
          ),
        ],
      ),
    );
  }
}
