import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/constants/storage_locations.dart';

enum FoodStatus { available, useSoon, expired, consumed, discarded }

/// A food record. Stored in the `food_items` table.
class FoodItemModel {
  const FoodItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.storage,
    required this.purchaseDate,
    required this.expirationDate,
    required this.addedAt,
    this.brand,
    this.openingDate,
    this.status = FoodStatus.available,
  });

  final String id;
  final String name;
  final String category;
  final int quantity;
  final String unit;
  final String? brand;
  final StorageLocation storage;
  final DateTime purchaseDate;
  final DateTime expirationDate;
  final DateTime? openingDate;
  final DateTime addedAt;
  final FoodStatus status;

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(
      expirationDate.year,
      expirationDate.month,
      expirationDate.day,
    );
    return exp.difference(today).inDays;
  }

  bool get isActive =>
      status != FoodStatus.consumed && status != FoodStatus.discarded;

  /// Consumed/discarded win; otherwise status is derived from the date.
  FoodStatus get effectiveStatus {
    if (!isActive) return status;
    final d = daysRemaining;
    if (d < 0) return FoodStatus.expired;
    if (d <= AppConstants.useSoonThresholdDays) return FoodStatus.useSoon;
    return FoodStatus.available;
  }

  FoodItemModel copyWith({FoodStatus? status}) => FoodItemModel(
        id: id,
        name: name,
        category: category,
        quantity: quantity,
        unit: unit,
        brand: brand,
        storage: storage,
        purchaseDate: purchaseDate,
        expirationDate: expirationDate,
        openingDate: openingDate,
        addedAt: addedAt,
        status: status ?? this.status,
      );

  /// [householdId] is a column, not a model field: items are always loaded
  /// already scoped to the current household. Omit it for updates.
  Map<String, Object?> toMap({String? householdId}) => {
        'id': id,
        'household_id': ?householdId,
        'name': name,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'brand': brand,
        'storage': storage.name,
        'purchase_date': purchaseDate.millisecondsSinceEpoch,
        'expiration_date': expirationDate.millisecondsSinceEpoch,
        'opening_date': openingDate?.millisecondsSinceEpoch,
        'status': status.name,
        'added_at': addedAt.millisecondsSinceEpoch,
      };

  factory FoodItemModel.fromMap(Map<String, Object?> map) {
    DateTime date(String key) =>
        DateTime.fromMillisecondsSinceEpoch(map[key]! as int);
    return FoodItemModel(
      id: map['id']! as String,
      name: map['name']! as String,
      category: map['category']! as String,
      quantity: map['quantity']! as int,
      unit: map['unit']! as String,
      brand: map['brand'] as String?,
      storage: StorageLocation.values.byName(map['storage']! as String),
      purchaseDate: date('purchase_date'),
      expirationDate: date('expiration_date'),
      openingDate: map['opening_date'] == null ? null : date('opening_date'),
      addedAt: date('added_at'),
      status: FoodStatus.values.byName(map['status']! as String),
    );
  }

  /// Demo records inserted by DevSeeder on first launch.
  static List<FoodItemModel> get mockList {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime day(int offset) => today.add(Duration(days: offset));

    return [
      FoodItemModel(
        id: 'f1',
        name: 'Fresh Milk',
        category: 'Dairy',
        quantity: 1,
        unit: 'L',
        brand: 'Magnolia',
        storage: StorageLocation.fridge,
        purchaseDate: day(-6),
        expirationDate: day(1),
        openingDate: day(-3),
        addedAt: day(-6),
      ),
      FoodItemModel(
        id: 'f2',
        name: 'Greek Yogurt',
        category: 'Dairy',
        quantity: 2,
        unit: 'cups',
        storage: StorageLocation.fridge,
        purchaseDate: day(-9),
        expirationDate: day(2),
        openingDate: day(-1),
        addedAt: day(-9),
      ),
      FoodItemModel(
        id: 'f3',
        name: 'Chicken Breast',
        category: 'Meat & Seafood',
        quantity: 500,
        unit: 'g',
        storage: StorageLocation.fridge,
        purchaseDate: day(-2),
        expirationDate: day(0),
        addedAt: day(-2),
      ),
      FoodItemModel(
        id: 'f4',
        name: 'Baby Spinach',
        category: 'Produce',
        quantity: 1,
        unit: 'bag',
        storage: StorageLocation.fridge,
        purchaseDate: day(-8),
        expirationDate: day(-1),
        addedAt: day(-8),
      ),
      FoodItemModel(
        id: 'f5',
        name: 'Leftover Adobo',
        category: 'Leftovers',
        quantity: 1,
        unit: 'box',
        storage: StorageLocation.fridge,
        purchaseDate: day(-3),
        expirationDate: day(2),
        openingDate: day(-3),
        addedAt: day(-3),
      ),
      FoodItemModel(
        id: 'f6',
        name: 'Eggs',
        category: 'Dairy',
        quantity: 12,
        unit: 'pcs',
        storage: StorageLocation.fridge,
        purchaseDate: day(-4),
        expirationDate: day(14),
        addedAt: day(-4),
      ),
      FoodItemModel(
        id: 'f7',
        name: 'Frozen Green Peas',
        category: 'Frozen',
        quantity: 2,
        unit: 'packs',
        storage: StorageLocation.freezer,
        purchaseDate: day(-30),
        expirationDate: day(150),
        addedAt: day(-30),
      ),
      FoodItemModel(
        id: 'f8',
        name: 'Longganisa',
        category: 'Meat & Seafood',
        quantity: 6,
        unit: 'pcs',
        storage: StorageLocation.freezer,
        purchaseDate: day(-10),
        expirationDate: day(60),
        addedAt: day(-10),
      ),
      FoodItemModel(
        id: 'f9',
        name: 'Jasmine Rice',
        category: 'Canned & Dry Goods',
        quantity: 5,
        unit: 'kg',
        storage: StorageLocation.pantry,
        purchaseDate: day(-20),
        expirationDate: day(300),
        addedAt: day(-20),
      ),
      FoodItemModel(
        id: 'f10',
        name: 'Canned Sardines',
        category: 'Canned & Dry Goods',
        quantity: 4,
        unit: 'cans',
        storage: StorageLocation.pantry,
        purchaseDate: day(-40),
        expirationDate: day(420),
        addedAt: day(-40),
      ),
      FoodItemModel(
        id: 'f11',
        name: 'Pandesal',
        category: 'Bakery',
        quantity: 10,
        unit: 'pcs',
        storage: StorageLocation.pantry,
        purchaseDate: day(-4),
        expirationDate: day(-2),
        addedAt: day(-4),
      ),
      FoodItemModel(
        id: 'f12',
        name: 'Soy Sauce',
        category: 'Condiments',
        quantity: 1,
        unit: 'bottle',
        storage: StorageLocation.cabinet,
        purchaseDate: day(-60),
        expirationDate: day(200),
        openingDate: day(-30),
        addedAt: day(-60),
      ),
      FoodItemModel(
        id: 'f13',
        name: 'Cheddar Cheese',
        category: 'Dairy',
        quantity: 1,
        unit: 'block',
        storage: StorageLocation.fridge,
        purchaseDate: day(-14),
        expirationDate: day(10),
        addedAt: day(-14),
        status: FoodStatus.consumed,
      ),
    ];
  }
}
