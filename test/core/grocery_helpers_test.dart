import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiration_reminder/core/constants/shelf_life.dart';
import 'package:food_expiration_reminder/core/constants/storage_locations.dart';
import 'package:food_expiration_reminder/core/utils/quantity_parser.dart';

void main() {
  test('parseQuantity splits a leading whole number from the unit', () {
    expect(parseQuantity('2 L'), (quantity: 2, unit: 'L'));
    expect(parseQuantity('500g'), (quantity: 500, unit: 'g'));
    expect(parseQuantity(' 1 tray '), (quantity: 1, unit: 'tray'));
    expect(parseQuantity('12'), (quantity: 12, unit: 'pcs'));
  });

  test('parseQuantity keeps anything else as one unit of it', () {
    expect(parseQuantity('a dozen'), (quantity: 1, unit: 'a dozen'));
    expect(parseQuantity('1.5 kg'), (quantity: 1, unit: '1.5 kg'));
    expect(parseQuantity('0'), (quantity: 1, unit: '0'));
    expect(parseQuantity(''), (quantity: 1, unit: 'pcs'));
  });

  test('shelf life depends on category and storage', () {
    expect(ShelfLife.estimateDays('Dairy', StorageLocation.fridge), 7);
    expect(
      ShelfLife.estimateDays('Meat & Seafood', StorageLocation.freezer),
      greaterThan(
        ShelfLife.estimateDays('Meat & Seafood', StorageLocation.fridge),
      ),
    );
    expect(
      ShelfLife.estimateDays(null, StorageLocation.pantry),
      ShelfLife.fallbackDays,
    );
  });
}
