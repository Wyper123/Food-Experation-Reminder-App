import 'package:food_expiration_reminder/data/local/database_helper.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:sqflite/sqflite.dart';

/// Food item persistence. Controllers depend on this interface only.
abstract class FoodDao {
  /// All items in the household, soonest expiration first.
  Future<List<FoodItemModel>> getAll(String householdId);
  Future<FoodItemModel?> getById(String id);
  Future<void> insert(FoodItemModel item, {required String householdId});
  Future<void> update(FoodItemModel item);
  Future<void> updateStatus(String id, FoodStatus status);
  Future<void> delete(String id);
}

class SqfliteFoodDao implements FoodDao {
  SqfliteFoodDao(this._helper);

  final DatabaseHelper _helper;
  static const _table = 'food_items';

  @override
  Future<List<FoodItemModel>> getAll(String householdId) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'household_id = ?',
      whereArgs: [householdId],
      orderBy: 'expiration_date ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(FoodItemModel.fromMap).toList();
  }

  @override
  Future<FoodItemModel?> getById(String id) async {
    final db = await _helper.database;
    final rows =
        await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : FoodItemModel.fromMap(rows.first);
  }

  @override
  Future<void> insert(FoodItemModel item, {required String householdId}) async {
    final db = await _helper.database;
    await db.insert(
      _table,
      item.toMap(householdId: householdId),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> update(FoodItemModel item) async {
    final db = await _helper.database;
    await db.update(_table, item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  @override
  Future<void> updateStatus(String id, FoodStatus status) async {
    final db = await _helper.database;
    await db.update(
      _table,
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await _helper.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
