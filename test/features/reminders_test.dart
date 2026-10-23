import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiration_reminder/core/constants/storage_locations.dart';
import 'package:food_expiration_reminder/data/local/app_preferences.dart';
import 'package:food_expiration_reminder/data/local/daos/food_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/notification_dao.dart';
import 'package:food_expiration_reminder/data/local/database_helper.dart';
import 'package:food_expiration_reminder/data/local/dev_seeder.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:food_expiration_reminder/data/models/reminder_settings.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/controllers/inventory_controller.dart';
import 'package:food_expiration_reminder/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:food_expiration_reminder/features/notifications/reminders/reminder_planner.dart';
import 'package:food_expiration_reminder/features/notifications/reminders/reminder_scheduler.dart';
import 'package:food_expiration_reminder/features/notifications/reminders/reminder_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';


FoodItemModel food(
  String id,
  DateTime expires, {
  FoodStatus status = FoodStatus.available,
}) =>
    FoodItemModel(
      id: id,
      name: 'Milk $id',
      category: 'Dairy',
      quantity: 1,
      unit: 'L',
      storage: StorageLocation.fridge,
      purchaseDate: DateTime(2026, 10, 1),
      expirationDate: expires,
      addedAt: DateTime(2026, 10, 1),
      status: status,
    );

void main() {
  group('planReminders', () {
    final expires = DateTime(2026, 11, 10);

    test('before, on the day and after, at the chosen time', () {
      final plan = planReminders(
        [food('a', expires)],
        const ReminderSettings(daysBefore: 2, hour: 9, minute: 30),
      );
      expect(plan.map((r) => r.kind), [
        ReminderKind.before,
        ReminderKind.dueToday,
        ReminderKind.expired,
      ]);
      expect(plan.map((r) => r.when), [
        DateTime(2026, 11, 8, 9, 30),
        DateTime(2026, 11, 10, 9, 30),
        DateTime(2026, 11, 11, 9, 30),
      ]);
      expect(plan.first.title, 'Milk a expires in 2 days');
      expect(plan[1].title, 'Milk a expires today');
    });

    test('respects day-only, expired alerts off and disabled', () {
      expect(
        planReminders(
          [food('a', expires)],
          const ReminderSettings(daysBefore: 0, expiredAlerts: false),
        ).map((r) => r.kind),
        [ReminderKind.dueToday],
      );
      expect(
        planReminders(
          [food('a', expires)],
          const ReminderSettings(enabled: false),
        ),
        isEmpty,
      );
    });

    test('skips consumed/discarded food and sorts across items', () {
      final plan = planReminders(
        [
          food('late', DateTime(2026, 12, 1)),
          food('gone', expires, status: FoodStatus.consumed),
          food('soon', expires),
        ],
        const ReminderSettings(daysBefore: 1),
      );
      expect(plan.first.foodId, 'soon');
      expect(plan.first.title, 'Milk soon expires tomorrow');
      expect(plan.map((r) => r.foodId), isNot(contains('gone')));
    });
  });

  group('ReminderSync', () {
    late DatabaseHelper db;
    late AppPreferences prefs;
    late NoopReminderScheduler scheduler;
    late InventoryController inventory;
    late NotificationsController inbox;
    late ReminderSync sync;
    late DateTime now;
    const hid = 'H-4B27';

    setUp(() async {
      sqfliteFfiInit();
      SharedPreferences.setMockInitialValues({});
      prefs = await AppPreferences.load();
      db = DatabaseHelper.inMemory(databaseFactoryFfi);
      await DevSeeder.seedIfEmpty(db);
      // Start from an empty inbox so only generated reminders show up.
      await (await db.database).delete('notifications');

      scheduler = NoopReminderScheduler();
      inventory = InventoryController(SqfliteFoodDao(db))..bind(hid);
      await inventory.refresh();
      inbox = NotificationsController(SqfliteNotificationDao(db))..bind(hid);
      await inbox.refresh();
      now = DateTime.now();
      sync = ReminderSync(
        scheduler: scheduler,
        notifications: SqfliteNotificationDao(db),
        prefs: prefs,
        inbox: inbox,
        clock: () => now,
      );
    });

    tearDown(() => db.close());

    test('schedules future reminders and backfills due ones once', () async {
      sync.update(inventory);
      await sync.idle;

      expect(scheduler.scheduled, isNotEmpty);
      expect(scheduler.scheduled.every((r) => r.when.isAfter(now)), isTrue);
      // Demo food expiring within two days has reminders already due.
      expect(inbox.items, isNotEmpty);
      final ids = inbox.items.map((n) => n.id).toSet();
      expect(ids.length, inbox.items.length, reason: 'one per reminder');

      // A deleted reminder is not re-added by later syncs.
      await inbox.delete(inbox.items.first.id);
      final remaining = inbox.items.length;
      sync.resync();
      await sync.idle;
      expect(inbox.items.length, remaining);
    });

    test('reschedules when food changes, not when nothing changed', () async {
      sync.update(inventory);
      await sync.idle;
      final before = scheduler.scheduled.length;

      sync.update(inventory);
      await sync.idle;
      expect(scheduler.scheduled.length, before);

      // Consuming an item removes its pending reminders.
      final item = inventory.active.firstWhere(
        (e) => scheduler.scheduled.any((r) => r.foodId == e.id),
      );
      await inventory.setStatus(item.id, FoodStatus.consumed);
      sync.update(inventory);
      await sync.idle;
      expect(scheduler.scheduled.where((r) => r.foodId == item.id), isEmpty);
    });

    test('turning reminders off or signing out clears the schedule',
        () async {
      sync.update(inventory);
      await sync.idle;
      expect(scheduler.scheduled, isNotEmpty);

      await prefs.setReminderSettings(
        prefs.reminderSettings.copyWith(enabled: false),
      );
      sync.update(inventory);
      await sync.idle;
      expect(scheduler.scheduled, isEmpty);

      await prefs.setReminderSettings(const ReminderSettings());
      sync.update(inventory);
      await sync.idle;
      expect(scheduler.scheduled, isNotEmpty);

      inventory.bind(null);
      sync.update(inventory);
      await sync.idle;
      expect(scheduler.scheduled, isEmpty);
    });
  });
}
