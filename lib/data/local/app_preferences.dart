import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/storage_locations.dart';
import 'package:food_expiration_reminder/data/models/reminder_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small device-level settings that live outside SQLite. Listeners rebuild when a preference changes.
class AppPreferences extends ChangeNotifier {
  AppPreferences._(this._prefs);

  static Future<AppPreferences> load() async =>
      AppPreferences._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _kAuthAccount = 'auth_account';
  static const _kThemeMode = 'theme_mode';
  static const _kDefaultStorage = 'default_storage';
  static const _kRemindEnabled = 'remind_enabled';
  static const _kRemindDaysBefore = 'remind_days_before';
  static const _kRemindHour = 'remind_hour';
  static const _kRemindMinute = 'remind_minute';
  static const _kRemindExpired = 'remind_expired';
  static const _kInboxSyncedUntil = 'inbox_synced_until_';

  /// The signed-in account as JSON (uid, email, name, provider), so the app
  /// reopens signed in, even offline. Not a UI preference: no notify.
  String? get authAccountJson => _prefs.getString(_kAuthAccount);

  Future<void> setAuthAccountJson(String? json) async {
    if (json == null) {
      await _prefs.remove(_kAuthAccount);
    } else {
      await _prefs.setString(_kAuthAccount, json);
    }
  }

  ThemeMode get themeMode =>
      ThemeMode.values.asNameMap()[_prefs.getString(_kThemeMode)] ??
      ThemeMode.system;

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_kThemeMode, mode.name);
    notifyListeners();
  }

  /// Pre-selected storage location when adding food.
  StorageLocation get defaultStorage =>
      StorageLocation.values.asNameMap()[_prefs.getString(_kDefaultStorage)] ??
      StorageLocation.fridge;

  Future<void> setDefaultStorage(StorageLocation storage) async {
    await _prefs.setString(_kDefaultStorage, storage.name);
    notifyListeners();
  }

  ReminderSettings get reminderSettings {
    const d = ReminderSettings();
    return ReminderSettings(
      enabled: _prefs.getBool(_kRemindEnabled) ?? d.enabled,
      daysBefore: _prefs.getInt(_kRemindDaysBefore) ?? d.daysBefore,
      hour: _prefs.getInt(_kRemindHour) ?? d.hour,
      minute: _prefs.getInt(_kRemindMinute) ?? d.minute,
      expiredAlerts: _prefs.getBool(_kRemindExpired) ?? d.expiredAlerts,
    );
  }

  Future<void> setReminderSettings(ReminderSettings s) async {
    await Future.wait([
      _prefs.setBool(_kRemindEnabled, s.enabled),
      _prefs.setInt(_kRemindDaysBefore, s.daysBefore),
      _prefs.setInt(_kRemindHour, s.hour),
      _prefs.setInt(_kRemindMinute, s.minute),
      _prefs.setBool(_kRemindExpired, s.expiredAlerts),
    ]);
    notifyListeners();
  }

  /// Reminders due up to this moment are already in the household's in-app
  /// inbox, so each one is added once even if the user later deletes it.
  DateTime? inboxSyncedUntil(String householdId) {
    final ms = _prefs.getInt('$_kInboxSyncedUntil$householdId');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Bookkeeping only, so it does not notify.
  Future<void> setInboxSyncedUntil(String householdId, DateTime at) =>
      _prefs.setInt('$_kInboxSyncedUntil$householdId', at.millisecondsSinceEpoch);
}
