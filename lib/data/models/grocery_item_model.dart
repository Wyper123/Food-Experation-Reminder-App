enum GroceryPriority { high, medium, low }

extension GroceryPriorityX on GroceryPriority {
  String get label => switch (this) {
        GroceryPriority.high => 'High',
        GroceryPriority.medium => 'Medium',
        GroceryPriority.low => 'Low',
      };
}

class GroceryItemModel {
  const GroceryItemModel({
    required this.id,
    required this.name,
    this.quantity = '1',
    this.priority = GroceryPriority.medium,
    this.isChecked = false,
    this.category,
  });

  final String id;
  final String name;
  final String quantity;
  final GroceryPriority priority;
  final bool isChecked;

  /// Optional; used to estimate shelf life when moved to the inventory.
  final String? category;

  GroceryItemModel copyWith({bool? isChecked}) => GroceryItemModel(
        id: id,
        name: name,
        quantity: quantity,
        priority: priority,
        isChecked: isChecked ?? this.isChecked,
        category: category,
      );

  Map<String, Object?> toMap({String? householdId}) => {
        'id': id,
        'household_id': ?householdId,
        'name': name,
        'quantity': quantity,
        'priority': priority.name,
        'is_checked': isChecked ? 1 : 0,
        'category': category,
      };

  factory GroceryItemModel.fromMap(Map<String, Object?> map) =>
      GroceryItemModel(
        id: map['id']! as String,
        name: map['name']! as String,
        quantity: map['quantity']! as String,
        priority: GroceryPriority.values.byName(map['priority']! as String),
        isChecked: map['is_checked'] == 1,
        category: map['category'] as String?,
      );

  /// Demo records inserted by DevSeeder on first launch.
  static List<GroceryItemModel> get mockList => const [
        GroceryItemModel(
          id: 'g1',
          name: 'Fresh Milk',
          quantity: '2 L',
          priority: GroceryPriority.high,
          category: 'Dairy',
        ),
        GroceryItemModel(
          id: 'g2',
          name: 'Eggs',
          quantity: '1 tray',
          priority: GroceryPriority.high,
          isChecked: true,
          category: 'Dairy',
        ),
        GroceryItemModel(
          id: 'g3',
          name: 'Bananas',
          quantity: '1 bunch',
          priority: GroceryPriority.medium,
          category: 'Produce',
        ),
        GroceryItemModel(
          id: 'g4',
          name: 'Cooking Oil',
          quantity: '1 bottle',
          priority: GroceryPriority.medium,
          category: 'Condiments',
        ),
        GroceryItemModel(
          id: 'g5',
          name: 'Tea Bags',
          quantity: '1 box',
          priority: GroceryPriority.low,
        ),
        GroceryItemModel(
          id: 'g6',
          name: 'Chocolate Spread',
          quantity: '1 jar',
          priority: GroceryPriority.low,
        ),
      ];
}
