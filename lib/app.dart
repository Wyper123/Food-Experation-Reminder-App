import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/theme/app_theme.dart';
import 'package:food_expiration_reminder/data/local/app_preferences.dart';
import 'package:food_expiration_reminder/data/local/daos/food_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/grocery_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/household_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/notification_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/user_dao.dart';
import 'package:food_expiration_reminder/data/local/database_helper.dart';
import 'package:food_expiration_reminder/features/auth/data/auth_service.dart';
import 'package:food_expiration_reminder/features/auth/presentation/controllers/session_controller.dart';
import 'package:food_expiration_reminder/features/auth/presentation/screens/startup_gate.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/controllers/inventory_controller.dart';
import 'package:food_expiration_reminder/features/grocery_list/presentation/controllers/grocery_controller.dart';
import 'package:food_expiration_reminder/features/household/presentation/controllers/household_controller.dart';
import 'package:food_expiration_reminder/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:food_expiration_reminder/features/notifications/reminders/reminder_scheduler.dart';
import 'package:food_expiration_reminder/features/notifications/reminders/reminder_sync.dart';
import 'package:provider/provider.dart';

/// Dependency wiring. Every controller is rebound to the current session, so
/// signing in/out (or switching household) reloads all data automatically.
class FoodExpirationApp extends StatelessWidget {
  const FoodExpirationApp({
    super.key,
    required this.database,
    required this.preferences,
    required this.scheduler,
    required this.auth,
  });

  final DatabaseHelper database;
  final AppPreferences preferences;
  final ReminderScheduler scheduler;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: preferences),
        Provider.value(value: scheduler),
        ChangeNotifierProvider(
          create: (_) => SessionController(
            users: SqfliteUserDao(database),
            households: SqfliteHouseholdDao(database),
            auth: auth,
          )..restore(),
        ),
        ChangeNotifierProxyProvider<SessionController, InventoryController>(
          create: (_) => InventoryController(SqfliteFoodDao(database)),
          update: (_, s, c) => c!..bind(s.householdId),
        ),
        ChangeNotifierProxyProvider<SessionController, GroceryController>(
          create: (_) => GroceryController(SqfliteGroceryDao(database)),
          update: (_, s, c) => c!..bind(s.householdId),
        ),
        ChangeNotifierProxyProvider<SessionController,
            NotificationsController>(
          create: (_) => NotificationsController(
            SqfliteNotificationDao(database),
          ),
          update: (_, s, c) => c!..bind(s.householdId),
        ),
        ChangeNotifierProxyProvider<SessionController, HouseholdController>(
          create: (_) => HouseholdController(SqfliteHouseholdDao(database)),
          update: (_, s, c) => c!..bindSession(s.userId, s.householdId),
        ),
        // Not read by any widget; created eagerly so it starts listening.
        ProxyProvider2<InventoryController, AppPreferences, ReminderSync>(
          lazy: false,
          create: (context) => ReminderSync(
            scheduler: scheduler,
            notifications: SqfliteNotificationDao(database),
            prefs: preferences,
            inbox: context.read<NotificationsController>(),
          ),
          update: (_, inventory, _, sync) => sync!..update(inventory),
        ),
      ],
      child: Consumer<AppPreferences>(
        builder: (context, prefs, _) => MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: prefs.themeMode,
          home: const StartupGate(),
        ),
      ),
    );
  }
}
