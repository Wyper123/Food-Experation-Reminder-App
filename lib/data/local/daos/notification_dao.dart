import 'package:food_expiration_reminder/data/local/database_helper.dart';
import 'package:food_expiration_reminder/data/models/notification_model.dart';
import 'package:sqflite/sqflite.dart';

/// In-app notification inbox persistence.
abstract class NotificationDao {
  /// Newest first.
  Future<List<NotificationModel>> getAll(String householdId);
  Future<void> insert(
    NotificationModel n, {
    required String householdId,
    String? foodId,
  });

  /// Like [insert], but silently skips a row whose id already exists.
  Future<void> insertIfAbsent(
    NotificationModel n, {
    required String householdId,
    String? foodId,
  });
  Future<void> markAllRead(String householdId);
  Future<void> delete(String id);
}

class SqfliteNotificationDao implements NotificationDao {
  SqfliteNotificationDao(this._helper);

  final DatabaseHelper _helper;
  static const _table = 'notifications';

  @override
  Future<List<NotificationModel>> getAll(String householdId) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'household_id = ?',
      whereArgs: [householdId],
      orderBy: 'created_at DESC',
    );
    return rows.map(NotificationModel.fromMap).toList();
  }

  @override
  Future<void> insert(
    NotificationModel n, {
    required String householdId,
    String? foodId,
  }) async {
    final db = await _helper.database;
    await db.insert(_table, n.toMap(householdId: householdId, foodId: foodId));
  }

  @override
  Future<void> insertIfAbsent(
    NotificationModel n, {
    required String householdId,
    String? foodId,
  }) async {
    final db = await _helper.database;
    await db.insert(
      _table,
      n.toMap(householdId: householdId, foodId: foodId),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<void> markAllRead(String householdId) async {
    final db = await _helper.database;
    await db.update(
      _table,
      {'is_read': 1},
      where: 'household_id = ?',
      whereArgs: [householdId],
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await _helper.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
