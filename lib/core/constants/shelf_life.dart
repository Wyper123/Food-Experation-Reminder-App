import 'package:food_expiration_reminder/core/constants/storage_locations.dart';

/// Rough shelf-life estimates (in days) used to pre-fill an expiration date
/// when groceries move into the inventory. Always shown as an estimate the
/// user confirms; the date printed on the package wins.
class ShelfLife {
  ShelfLife._();

  static const int fallbackDays = 7;

  static const Map<String, Map<StorageLocation, int>> _days = {
    'Dairy': {
      StorageLocation.fridge: 7,
      StorageLocation.freezer: 90,
      StorageLocation.pantry: 1,
      StorageLocation.cabinet: 1,
    },
    'Meat & Seafood': {
      StorageLocation.fridge: 2,
      StorageLocation.freezer: 120,
      StorageLocation.pantry: 1,
      StorageLocation.cabinet: 1,
    },
    'Fruits': {
      StorageLocation.fridge: 7,
      StorageLocation.freezer: 240,
      StorageLocation.pantry: 5,
      StorageLocation.cabinet: 5,
    },
    'Vegetables': {
      StorageLocation.fridge: 7,
      StorageLocation.freezer: 240,
      StorageLocation.pantry: 4,
      StorageLocation.cabinet: 4,
    },
    'Produce': {
      StorageLocation.fridge: 7,
      StorageLocation.freezer: 240,
      StorageLocation.pantry: 4,
      StorageLocation.cabinet: 4,
    },
    'Bakery': {
      StorageLocation.fridge: 7,
      StorageLocation.freezer: 90,
      StorageLocation.pantry: 4,
      StorageLocation.cabinet: 4,
    },
    'Beverages': {
      StorageLocation.fridge: 10,
      StorageLocation.freezer: 180,
      StorageLocation.pantry: 180,
      StorageLocation.cabinet: 180,
    },
    'Canned & Dry Goods': {
      StorageLocation.fridge: 365,
      StorageLocation.freezer: 365,
      StorageLocation.pantry: 365,
      StorageLocation.cabinet: 365,
    },
    'Condiments': {
      StorageLocation.fridge: 180,
      StorageLocation.freezer: 365,
      StorageLocation.pantry: 365,
      StorageLocation.cabinet: 365,
    },
    'Leftovers': {
      StorageLocation.fridge: 3,
      StorageLocation.freezer: 60,
      StorageLocation.pantry: 1,
      StorageLocation.cabinet: 1,
    },
    'Frozen': {
      StorageLocation.fridge: 2,
      StorageLocation.freezer: 180,
      StorageLocation.pantry: 1,
      StorageLocation.cabinet: 1,
    },
    'Snacks': {
      StorageLocation.fridge: 90,
      StorageLocation.freezer: 180,
      StorageLocation.pantry: 90,
      StorageLocation.cabinet: 90,
    },
  };

  static int estimateDays(String? category, StorageLocation storage) =>
      _days[category]?[storage] ?? fallbackDays;
}
