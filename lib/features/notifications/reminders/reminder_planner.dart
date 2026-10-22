import 'package:food_expiration_reminder/core/constants/storage_locations.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:food_expiration_reminder/data/models/notification_model.dart';
import 'package:food_expiration_reminder/data/models/reminder_settings.dart';

enum ReminderKind { before, dueToday, expired }

/// One reminder for one food item at one moment.
class PlannedReminder {
  const PlannedReminder({
    required this.foodId,
    required this.kind,
    required this.when,
    required this.title,
    required this.body,
  });

  final String foodId;
  final ReminderKind kind;
  final DateTime when;
  final String title;
  final String body;

  NotificationType get inboxType => kind == ReminderKind.expired
      ? NotificationType.expired
      : NotificationType.expiringSoon;

  /// Stable per item, kind and day, so the inbox never stores it twice.
  String get inboxId =>
      'rem-$foodId-${kind.name}-${when.year}${when.month}${when.day}';
}

/// Every reminder the [items] call for under [settings], soonest first,
/// including ones already in the past. Consumed/discarded items get none.
List<PlannedReminder> planReminders(
  List<FoodItemModel> items,
  ReminderSettings settings,
) {
  if (!settings.enabled) return const [];
  final plan = <PlannedReminder>[];
  for (final item in items) {
    if (!item.isActive) continue;
    final exp = item.expirationDate;
    DateTime at(int dayOffset) => DateTime(
          exp.year,
          exp.month,
          exp.day + dayOffset,
          settings.hour,
          settings.minute,
        );
    final where = 'Stored in ${item.storage.label}';

    final d = settings.daysBefore;
    if (d > 0) {
      plan.add(
        PlannedReminder(
          foodId: item.id,
          kind: ReminderKind.before,
          when: at(-d),
          title: d == 1
              ? '${item.name} expires tomorrow'
              : '${item.name} expires in $d days',
          body: '$where. Plan to use it soon.',
        ),
      );
    }
    plan.add(
      PlannedReminder(
        foodId: item.id,
        kind: ReminderKind.dueToday,
        when: at(0),
        title: '${item.name} expires today',
        body: '$where. Use it or freeze it today.',
      ),
    );
    if (settings.expiredAlerts) {
      plan.add(
        PlannedReminder(
          foodId: item.id,
          kind: ReminderKind.expired,
          when: at(1),
          title: '${item.name} has expired',
          body: 'Mark it as consumed or discarded to keep your list tidy.',
        ),
      );
    }
  }
  plan.sort((a, b) => a.when.compareTo(b.when));
  return plan;
}
