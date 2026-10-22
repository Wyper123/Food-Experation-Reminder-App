import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiration_reminder/core/constants/storage_locations.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:food_expiration_reminder/features/food_inventory/inventory_csv.dart';

void main() {
  FoodItemModel item(String name, DateTime exp, {String? brand}) =>
      FoodItemModel(
        id: name,
        name: name,
        category: 'Dairy',
        quantity: 2,
        unit: 'L',
        brand: brand,
        storage: StorageLocation.fridge,
        purchaseDate: DateTime(2026, 10, 1),
        expirationDate: exp,
        addedAt: DateTime(2026, 10, 1),
        status: FoodStatus.consumed,
      );

  test('header, ISO dates, soonest first, CRLF rows', () {
    final csv = inventoryToCsv([
      item('Yogurt', DateTime(2026, 12, 1)),
      item('Milk', DateTime(2026, 11, 1)),
    ]);
    final lines = csv.split('\r\n');
    expect(lines.first, startsWith('Name,Category,Quantity,Unit'));
    expect(lines[1], 'Milk,Dairy,2,L,,Refrigerator,2026-10-01,2026-11-01,,'
        'Consumed,');
    expect(lines[2], startsWith('Yogurt,'));
    expect(csv, endsWith('\r\n'));
  });

  test('quotes cells containing commas, quotes or newlines', () {
    final csv = inventoryToCsv([
      item('Cheese, "aged"', DateTime(2026, 11, 1), brand: 'Line\nBreak'),
    ]);
    expect(csv, contains('"Cheese, ""aged""",'));
    expect(csv, contains('"Line\nBreak"'));
  });
}
