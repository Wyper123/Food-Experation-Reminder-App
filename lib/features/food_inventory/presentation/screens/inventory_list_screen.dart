import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/constants/storage_locations.dart';
import 'package:food_expiration_reminder/core/widgets/custom_text_field.dart';
import 'package:food_expiration_reminder/core/widgets/empty_state_widget.dart';
import 'package:food_expiration_reminder/core/widgets/filter_chip_bar.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/controllers/inventory_controller.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/screens/add_edit_food_screen.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/screens/food_detail_screen.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/widgets/food_card.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/widgets/food_list_skeleton.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/widgets/storage_filter_tabs.dart';
import 'package:provider/provider.dart';

enum InventorySort { expiration, name, dateAdded }

extension InventorySortX on InventorySort {
  String get label => switch (this) {
        InventorySort.expiration => 'Expiration date',
        InventorySort.name => 'Name',
        InventorySort.dateAdded => 'Date added',
      };

  IconData get icon => switch (this) {
        InventorySort.expiration => Icons.event_rounded,
        InventorySort.name => Icons.sort_by_alpha_rounded,
        InventorySort.dateAdded => Icons.history_rounded,
      };
}

/// Status chips. Shared with the dashboard, whose counters open the
/// inventory pre-filtered.
enum InventoryStatusFilter { all, useSoon, expired, usedUp }

extension InventoryStatusFilterX on InventoryStatusFilter {
  String get label => switch (this) {
        InventoryStatusFilter.all => 'All',
        InventoryStatusFilter.useSoon => 'Use soon',
        InventoryStatusFilter.expired => 'Expired',
        InventoryStatusFilter.usedUp => 'Used up',
      };

  bool matches(FoodItemModel item) => switch (this) {
        InventoryStatusFilter.all => true,
        InventoryStatusFilter.useSoon =>
          item.effectiveStatus == FoodStatus.useSoon,
        InventoryStatusFilter.expired =>
          item.effectiveStatus == FoodStatus.expired,
        InventoryStatusFilter.usedUp => !item.isActive,
      };
}

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key, required this.statusFilter});

  /// Owned by the navigation shell so other tabs can set it.
  final ValueNotifier<InventoryStatusFilter> statusFilter;

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final _search = TextEditingController();
  StorageLocation? _storage;
  InventorySort _sort = InventorySort.expiration;

  @override
  void initState() {
    super.initState();
    widget.statusFilter.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    widget.statusFilter.removeListener(_onFilterChanged);
    _search.dispose();
    super.dispose();
  }

  void _onFilterChanged() => setState(() {});

  InventoryStatusFilter get _status => widget.statusFilter.value;

  /// Filtering/sorting happens in memory over the controller's list, so the
  /// dashboard and this screen always agree.
  List<FoodItemModel> _visible(List<FoodItemModel> items) {
    final q = _search.text.trim().toLowerCase();
    final list = items.where((e) {
      if (!_status.matches(e)) return false;
      if (_storage != null && e.storage != _storage) return false;
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.category.toLowerCase().contains(q);
    }).toList();

    list.sort((a, b) {
      // Consumed/discarded items always sink to the bottom.
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return switch (_sort) {
        InventorySort.expiration =>
          a.expirationDate.compareTo(b.expirationDate),
        InventorySort.name => a.name.compareTo(b.name),
        InventorySort.dateAdded => b.addedAt.compareTo(a.addedAt),
      };
    });
    return list;
  }

  Future<void> _pickSort() async {
    final picked = await showModalBottomSheet<InventorySort>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Sort by', style: AppTextStyles.title),
            ),
            for (final s in InventorySort.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Icon(s.icon),
                title: Text(s.label),
                trailing: s == _sort
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(ctx).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop(s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _sort = picked);
  }

  void _openDetail(FoodItemModel item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FoodDetailScreen(itemId: item.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inventory = context.watch<InventoryController>();
    final isLoading = inventory.isLoading;
    final visible = _visible(inventory.items);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'inventory-fab',
        tooltip: 'Add food',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditFoodScreen()),
        ),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              4,
              AppConstants.pagePadding,
              12,
            ),
            child: CustomTextField(
              label: 'Search food or category',
              controller: _search,
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
          StorageFilterTabs(
            selected: _storage,
            onChanged: (s) => setState(() => _storage = s),
          ),
          const SizedBox(height: 8),
          FilterChipBar(
            options: [
              for (final f in InventoryStatusFilter.values) f.label,
            ],
            selected: _status.label,
            onSelected: (label) => widget.statusFilter.value =
                InventoryStatusFilter.values
                    .firstWhere((f) => f.label == label),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              8,
              8,
              0,
            ),
            child: Row(
              children: [
                Text(
                  isLoading ? 'Loading items…' : '${visible.length} items',
                  style: AppTextStyles.caption.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickSort,
                  icon: const Icon(Icons.swap_vert_rounded, size: 20),
                  label: Text(_sort.label),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: inventory.refresh,
              child: inventory.error != null && inventory.items.isEmpty
                  ? ListView(
                      children: [
                        EmptyStateWidget(
                          icon: Icons.cloud_off_rounded,
                          title: 'Could not load your food',
                          message: 'Pull down or tap below to try again.',
                          actionLabel: 'Try again',
                          onAction: inventory.refresh,
                        ),
                      ],
                    )
                  : isLoading
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppConstants.pagePadding,
                            4,
                            AppConstants.pagePadding,
                            96,
                          ),
                          children: const [FoodListSkeleton()],
                        )
                      : visible.isEmpty
                          ? ListView(
                              children: [_buildEmpty(inventory.items.isEmpty)],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                AppConstants.pagePadding,
                                4,
                                AppConstants.pagePadding,
                                96,
                              ),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) => FoodCard(
                                item: visible[i],
                                onTap: () => _openDetail(visible[i]),
                              ),
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool kitchenEmpty) {
    if (kitchenEmpty) {
      return EmptyStateWidget(
        icon: Icons.kitchen_outlined,
        title: 'Your kitchen is empty',
        message: 'Add the food you have to start tracking expiry dates.',
        actionLabel: 'Add food',
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditFoodScreen()),
        ),
      );
    }
    final filtered = _search.text.trim().isNotEmpty ||
        _storage != null ||
        _status != InventoryStatusFilter.all;
    return EmptyStateWidget(
      icon: Icons.search_off_rounded,
      title: switch (_status) {
        InventoryStatusFilter.useSoon => 'Nothing to use soon',
        InventoryStatusFilter.expired => 'Nothing has expired',
        InventoryStatusFilter.usedUp => 'No used-up items yet',
        InventoryStatusFilter.all => 'No matching food',
      },
      message: 'Try a different search or filter.',
      actionLabel: filtered ? 'Clear filters' : null,
      onAction: filtered
          ? () {
              _search.clear();
              setState(() => _storage = null);
              widget.statusFilter.value = InventoryStatusFilter.all;
            }
          : null,
    );
  }
}
