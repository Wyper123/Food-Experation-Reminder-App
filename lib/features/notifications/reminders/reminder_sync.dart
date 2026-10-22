import 'package:flutter/foundation.dart';
import 'package:food_expiration_reminder/data/local/app_preferences.dart';
import 'package:food_expiration_reminder/data/local/daos/notification_dao.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:food_expiration_reminder/data/models/notification_model.dart';
import 'package:food_expiration_reminder/data/models/reminder_settings.dart';
import 'package:food_expiration_reminder/features/food_inventory/presentation/controllers/inventory_controller.dart';
import 'package:food_expiration_reminder/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:food_expiration_reminder/features/notifications/reminders/reminder_planner.dart';
import 'package:food_expiration_reminder/features/notifications/reminders/reminder_scheduler.dart';

/// Keeps system notifications and the in-app inbox in step with the
/// inventory and reminder settings. Driven by [update], which the provider
/// tree calls whenever either changes.
class ReminderSync {
  ReminderSync({
    required this._scheduler,
    required this._notifications,
    required this._prefs,
    required this._inbox,
    this._clock = DateTime.now,
  });

  final ReminderScheduler _scheduler;
  final NotificationDao _notifications;
  final AppPreferences _prefs;
  final NotificationsController _inbox;
  final DateTime Function() _clock;

  /// First sync for a household backfills reminders due this recently.
  static const backfill = Duration(days: 2);

  String? _lastSignature;
  InventoryController? _lastInventory;
  Future<void> _queue = Future.value();

  /// Completes when all queued work is done (used by tests).
  Future<void> get idle => _queue;

  void update(InventoryController inventory) {
    _lastInventory = inventory;
    if (inventory.isLoading && inventory.scopeId != null) return;

    final householdId = inventory.scopeId;
    final settings = _prefs.reminderSettings;
    final items = List<FoodItemModel>.of(inventory.items);
    final signature = householdId == null
        ? 'signed-out'
        : [
            householdId,
            settings.signature,
            for (final e in items)
              '${e.id}:${e.name}:${e.storage.name}:'
                  '${e.expirationDate.millisecondsSinceEpoch}:${e.status.name}',
          ].join('|');
    if (signature == _lastSignature) return;
    _lastSignature = signature;

    // Runs after the current build; work is serialised so an older sync can
    // never overwrite a newer one.
    _queue = _queue.then((_) => _sync(householdId, items, settings)).catchError(
      (Object e, StackTrace st) =>
          debugPrint('Reminder sync failed: $e\n$st'),
    );
  }

  /// Re-runs the last sync, e.g. when the app returns to the foreground
  /// and reminders may have come due in the meantime.
  void resync() {
    _lastSignature = null;
    final inventory = _lastInventory;
    if (inventory != null) update(inventory);
  }

  Future<void> _sync(
    String? householdId,
    List<FoodItemModel> items,
    ReminderSettings settings,
  ) async {
    // Signed out: nobody's food should keep notifying on this device.
    if (householdId == null) return _scheduler.replaceAll(const []);

    final plan = planReminders(items, settings);
    await _scheduler.replaceAll(plan);
    await _fillInbox(householdId, plan);
  }

  /// Copies reminders that came due since the last sync into the inbox,
  /// at most one (the latest) per food item.
  Future<void> _fillInbox(String householdId, List<PlannedReminder> plan) async {
    final now = _clock();
    final since =
        _prefs.inboxSyncedUntil(householdId) ?? now.subtract(backfill);
    final latest = <String, PlannedReminder>{};
    for (final r in plan) {
      if (r.when.isAfter(since) && !r.when.isAfter(now)) latest[r.foodId] = r;
    }
    for (final r in latest.values) {
      await _notifications.insertIfAbsent(
        NotificationModel(
          id: r.inboxId,
          title: r.title,
          body: r.body,
          type: r.inboxType,
          createdAt: r.when,
        ),
        householdId: householdId,
        foodId: r.foodId,
      );
    }
    await _prefs.setInboxSyncedUntil(householdId, now);
    if (latest.isNotEmpty) await _inbox.refresh();
  }
}
