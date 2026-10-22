import 'package:food_expiration_reminder/core/state/scoped_controller.dart';
import 'package:food_expiration_reminder/data/local/daos/grocery_dao.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:food_expiration_reminder/data/models/grocery_item_model.dart';

class GroceryController extends ScopedController<List<GroceryItemModel>> {
  GroceryController(this._dao);

  final GroceryDao _dao;

  @override
  Future<List<GroceryItemModel>> fetch(String scopeId) => _dao.getAll(scopeId);

  List<GroceryItemModel> get items => data ?? const [];
  List<GroceryItemModel> get checked =>
      items.where((e) => e.isChecked).toList();

  Future<void> add(GroceryItemModel item) async {
    await _dao.insert(item, householdId: scopeId!);
    data = [...items, item];
  }

  Future<void> update(GroceryItemModel item) async {
    await _dao.update(item);
    data = [for (final e in items) e.id == item.id ? item : e];
  }

  Future<void> setChecked(String id, bool checked) async {
    await _dao.setChecked(id, checked);
    data = [
      for (final e in items) e.id == id ? e.copyWith(isChecked: checked) : e,
    ];
  }

  Future<void> setAllChecked(bool checked) async {
    await _dao.setAllChecked(scopeId!, checked);
    data = [for (final e in items) e.copyWith(isChecked: checked)];
  }

  Future<void> delete(String id) async {
    await _dao.delete(id);
    data = items.where((e) => e.id != id).toList();
  }

  /// Creates [foods] in the inventory and removes [groceryIds] from the
  /// list atomically. Refresh the InventoryController afterwards.
  Future<void> moveToInventory(
    List<String> groceryIds,
    List<FoodItemModel> foods,
  ) async {
    await _dao.moveToInventory(groceryIds, foods, householdId: scopeId!);
    final moved = groceryIds.toSet();
    data = items.where((e) => !moved.contains(e.id)).toList();
  }
}
