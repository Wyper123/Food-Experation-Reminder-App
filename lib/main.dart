import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/app.dart';
import 'package:food_expiration_reminder/core/security/password_hasher.dart';
import 'package:food_expiration_reminder/core/widgets/startup_error_app.dart';
import 'package:food_expiration_reminder/data/local/app_preferences.dart';
import 'package:food_expiration_reminder/data/local/database_helper.dart';
import 'package:food_expiration_reminder/data/local/dev_seeder.dart';
import 'package:food_expiration_reminder/features/notifications/reminders/reminder_scheduler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android/iOS use the platform sqflite plugin; desktop needs the FFI one.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Anything thrown before runApp would otherwise leave the launch screen up
  // forever, so startup failures get their own screen.
  try {
    const hasher = PasswordHasher();
    final database = DatabaseHelper.instance;
    final preferences = await AppPreferences.load();
    if (kDebugMode) await DevSeeder.seedIfEmpty(database, hasher);

    runApp(
      FoodExpirationApp(
        database: database,
        preferences: preferences,
        scheduler: await _startReminders(),
        hasher: hasher,
      ),
    );
  } catch (e, st) {
    debugPrint('Startup failed: $e\n$st');
    runApp(StartupErrorApp(error: e));
  }
}

/// The app still works without system notifications, so a failing or slow
/// notification setup falls back to none instead of blocking startup.
Future<ReminderScheduler> _startReminders() async {
  final scheduler = ReminderScheduler.forPlatform();
  try {
    await scheduler.init().timeout(const Duration(seconds: 5));
    return scheduler;
  } catch (e) {
    debugPrint('Notifications unavailable: $e');
    return NoopReminderScheduler();
  }
}
