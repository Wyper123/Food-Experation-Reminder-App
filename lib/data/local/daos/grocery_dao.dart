import 'package:food_expiration_reminder/data/local/database_helper.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:food_expiration_reminder/data/models/grocery_item_model.dart';

/// Grocery list persistence.
abstract class GroceryDao {
  /// All items in the household, oldest first.
  Future<List<GroceryItemModel>> getAll(String householdId);
  Future<void> insert(GroceryItemModel item, {required String householdId});
  Future<void> update(GroceryItemModel item);
  Future<void> setChecked(String id, bool checked);
  Future<void> setAllChecked(String householdId, bool checked);
  Future<void> delete(String id);
  Future<void> deleteChecked(String householdId);

  /// Inserts [foods] and deletes the grocery rows [groceryIds] in one
  /// transaction: either everything moves or nothing changes.
  Future<void> moveToInventory(
    List<String> groceryIds,
    List<FoodItemModel> foods, {
    required String householdId,
  });
}

class SqfliteGroceryDao implements GroceryDao {
  SqfliteGroceryDao(this._helper);

  final DatabaseHelper _helper;
  static const _table = 'grocery_items';

  @override
  Future<List<GroceryItemModel>> getAll(String householdId) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'household_id = ?',
      whereArgs: [householdId],
      orderBy: 'created_at ASC',
    );
    return rows.map(GroceryItemModel.fromMap).toList();
  }

  @override
  Future<void> insert(
    GroceryItemModel item, {
    required String householdId,
  }) async {
    final db = await _helper.database;
    await db.insert(_table, {
      ...item.toMap(householdId: householdId),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> update(GroceryItemModel item) async {
    final db = await _helper.database;
    await db.update(
      _table,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<void> setChecked(String id, bool checked) async {
    final db = await _helper.database;
    await db.update(
      _table,
      {'is_checked': checked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> setAllChecked(String householdId, bool checked) async {
    final db = await _helper.database;
    await db.update(
      _table,
      {'is_checked': checked ? 1 : 0},
      where: 'household_id = ?',
      whereArgs: [householdId],
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await _helper.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteChecked(String householdId) async {
    final db = await _helper.database;
    await db.delete(
      _table,
      where: 'household_id = ? AND is_checked = 1',
      whereArgs: [householdId],
    );
  }

  @override
  Future<void> moveToInventory(
    List<String> groceryIds,
    List<FoodItemModel> foods, {
    required String householdId,
  }) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      for (final f in foods) {
        await txn.insert('food_items', f.toMap(householdId: householdId));
      }
      for (final id in groceryIds) {
        await txn.delete(
          _table,
          where: 'id = ? AND household_id = ?',
          whereArgs: [id, householdId],
        );
      }
    });
  }
}
