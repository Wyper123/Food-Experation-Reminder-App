import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/app.dart';
import 'package:food_expiration_reminder/core/security/password_hasher.dart';
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

  const hasher = PasswordHasher();
  final database = DatabaseHelper.instance;
  final preferences = await AppPreferences.load();
  if (kDebugMode) await DevSeeder.seedIfEmpty(database, hasher);
  var scheduler = ReminderScheduler.forPlatform();
  try {
    await scheduler.init();
  } catch (e) {
    // The app still works without system notifications.
    debugPrint('Notifications unavailable: $e');
    scheduler = NoopReminderScheduler();
  }

  runApp(
    FoodExpirationApp(
      database: database,
      preferences: preferences,
      scheduler: scheduler,
      hasher: hasher,
    ),
  );
}
