import 'package:food_expiration_reminder/core/state/scoped_controller.dart';
import 'package:food_expiration_reminder/data/local/daos/food_dao.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';

/// Single source of truth for the household's food items. Dashboard,
/// inventory, detail and profile stats all read from here.
class InventoryController extends ScopedController<List<FoodItemModel>> {
  InventoryController(this._dao);

  final FoodDao _dao;

  @override
  Future<List<FoodItemModel>> fetch(String scopeId) => _dao.getAll(scopeId);

  List<FoodItemModel> get items => data ?? const [];

  /// Not consumed or discarded.
  List<FoodItemModel> get active => items.where((e) => e.isActive).toList();

  FoodItemModel? byId(String id) {
    for (final e in items) {
      if (e.id == id) return e;
    }
    return null;
  }

  int countByStatus(FoodStatus status) =>
      items.where((e) => e.effectiveStatus == status).length;

  Future<void> add(FoodItemModel item) async {
    await _dao.insert(item, householdId: scopeId!);
    data = [...items, item]
      ..sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
  }

  Future<void> update(FoodItemModel item) async {
    await _dao.update(item);
    data = [for (final e in items) e.id == item.id ? item : e];
  }

  Future<void> setStatus(String id, FoodStatus status) async {
    await _dao.updateStatus(id, status);
    data = [for (final e in items) e.id == id ? e.copyWith(status: status) : e];
  }

  Future<void> delete(String id) async {
    await _dao.delete(id);
    data = items.where((e) => e.id != id).toList();
  }
}
