import 'package:food_expiration_reminder/core/constants/app_constants.dart';

/// How and when expiration reminders are delivered. Stored per device.
class ReminderSettings {
  const ReminderSettings({
    this.enabled = true,
    this.daysBefore = AppConstants.useSoonThresholdDays,
    this.hour = 8,
    this.minute = 0,
    this.expiredAlerts = true,
  });

  final bool enabled;

  /// Advance warning; 0 means only on the expiration day itself.
  final int daysBefore;

  /// Time of day reminders arrive.
  final int hour;
  final int minute;

  /// Also remind the day after something expires.
  final bool expiredAlerts;

  ReminderSettings copyWith({
    bool? enabled,
    int? daysBefore,
    int? hour,
    int? minute,
    bool? expiredAlerts,
  }) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        daysBefore: daysBefore ?? this.daysBefore,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        expiredAlerts: expiredAlerts ?? this.expiredAlerts,
      );

  /// Changes whenever any setting changes; used to skip redundant work.
  String get signature => '$enabled|$daysBefore|$hour:$minute|$expiredAlerts';
}
