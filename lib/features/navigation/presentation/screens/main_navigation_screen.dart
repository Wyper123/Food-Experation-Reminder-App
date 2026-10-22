import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/data/local/app_preferences.dart';
import 'package:food_expiration_reminder/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/screens/inventory_list_screen.dart';
import 'package:food_expiration_reminder/features/grocery_list/presentation/screens/grocery_list_screen.dart';
import 'package:food_expiration_reminder/features/household/presentation/screens/household_screen.dart';
import 'package:food_expiration_reminder/features/notifications/reminders/reminder_scheduler.dart';
import 'package:food_expiration_reminder/features/notifications/reminders/reminder_sync.dart';
import 'package:food_expiration_reminder/features/profile/presentation/screens/profile_screen.dart';
import 'package:provider/provider.dart';

/// App shell with a persistent bottom navigation bar.
/// IndexedStack keeps each tab's scroll position and state alive.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  late int _index = widget.initialIndex;
  final _inventoryFilter = ValueNotifier(InventoryStatusFilter.all);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Android 13+ shows the system prompt once; later calls are silent.
    if (context.read<AppPreferences>().reminderSettings.enabled) {
      context.read<ReminderScheduler>().requestPermission();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reminders may have come due while the app was in the background.
    if (state == AppLifecycleState.resumed) {
      context.read<ReminderSync>().resync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inventoryFilter.dispose();
    super.dispose();
  }

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.space_dashboard_outlined),
      selectedIcon: Icon(Icons.space_dashboard_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.kitchen_outlined),
      selectedIcon: Icon(Icons.kitchen_rounded),
      label: 'Inventory',
    ),
    NavigationDestination(
      icon: Icon(Icons.shopping_basket_outlined),
      selectedIcon: Icon(Icons.shopping_basket_rounded),
      label: 'Groceries',
    ),
    NavigationDestination(
      icon: Icon(Icons.groups_outlined),
      selectedIcon: Icon(Icons.groups_rounded),
      label: 'Household',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(
            onViewInventory: (filter) {
              _inventoryFilter.value = filter;
              _select(1);
            },
            onViewGroceries: () => _select(2),
          ),
          InventoryListScreen(statusFilter: _inventoryFilter),
          const GroceryListScreen(),
          const HouseholdScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: _destinations,
      ),
    );
  }
}
