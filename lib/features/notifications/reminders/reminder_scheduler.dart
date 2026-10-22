import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:food_expiration_reminder/features/notifications/reminders/reminder_planner.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Delivers reminders as system notifications. The app depends on this
/// interface so tests and unsupported platforms can swap in [NoopReminderScheduler].
abstract class ReminderScheduler {
  Future<void> init();

  /// Asks for permission (Android 13+). True when notifications may be shown.
  Future<bool> requestPermission();

  Future<bool> isPermitted();

  /// Replaces every pending notification with [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders);

  /// Shows a sample right away so the user can check their settings.
  Future<void> showTest();

  /// Android allows roughly 500 pending alarms per app; stay far below.
  static const int maxPending = 60;

  /// Picks the platform implementation.
  static ReminderScheduler forPlatform() {
    final supported = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return supported ? LocalNotificationScheduler() : NoopReminderScheduler();
  }
}

class LocalNotificationScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'expiry_reminders',
      'Expiration reminders',
      channelDescription: 'Alerts before and when your food expires',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      // Falls back to UTC; reminders may then arrive at the wrong hour.
      debugPrint('Could not read device time zone: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is requested explicitly via requestPermission().
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<bool> isPermitted() async =>
      await _android?.areNotificationsEnabled() ?? true;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await _plugin.cancelAllPendingNotifications();
    final now = DateTime.now();
    final upcoming = reminders
        .where((r) => r.when.isAfter(now))
        .take(ReminderScheduler.maxPending);
    var id = 0;
    for (final r in upcoming) {
      await _plugin.zonedSchedule(
        id: id++,
        scheduledDate: tz.TZDateTime.from(r.when, tz.local),
        notificationDetails: _details,
        // Inexact: no special alarm permission needed; may arrive a few
        // minutes late, which is fine for daily food reminders.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        payload: r.foodId,
      );
    }
  }

  @override
  Future<void> showTest() => _plugin.show(
        // Outside the range used by scheduled reminders.
        id: 100000,
        title: 'Reminders are working',
        body: "You'll be notified like this before food expires.",
        notificationDetails: _details,
      );
}

/// Does nothing; records what it was asked to do (used in tests).
class NoopReminderScheduler implements ReminderScheduler {
  List<PlannedReminder> scheduled = const [];
  int testsShown = 0;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> isPermitted() async => true;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    final now = DateTime.now();
    scheduled = reminders
        .where((r) => r.when.isAfter(now))
        .take(ReminderScheduler.maxPending)
        .toList();
  }

  @override
  Future<void> showTest() async => testsShown++;
}
