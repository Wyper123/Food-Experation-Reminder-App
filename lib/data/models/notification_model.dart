enum NotificationType { expiringSoon, expired, grocery, household }

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        title: title,
        body: body,
        type: type,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );

  Map<String, Object?> toMap({required String householdId, String? foodId}) =>
      {
        'id': id,
        'household_id': householdId,
        'food_id': foodId,
        'title': title,
        'body': body,
        'type': type.name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'is_read': isRead ? 1 : 0,
      };

  factory NotificationModel.fromMap(Map<String, Object?> map) =>
      NotificationModel(
        id: map['id']! as String,
        title: map['title']! as String,
        body: map['body']! as String,
        type: NotificationType.values.byName(map['type']! as String),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
        isRead: map['is_read'] == 1,
      );

  /// Demo records inserted by DevSeeder on first launch.
  static List<NotificationModel> get mockList {
    final now = DateTime.now();
    return [
      NotificationModel(
        id: 'n1',
        title: 'Chicken Breast expires today',
        body: 'Cook it or freeze it before the day ends.',
        type: NotificationType.expiringSoon,
        createdAt: now.subtract(const Duration(minutes: 20)),
      ),
      NotificationModel(
        id: 'n2',
        title: 'Fresh Milk expires tomorrow',
        body: 'Opened 3 days ago in the Fridge.',
        type: NotificationType.expiringSoon,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      NotificationModel(
        id: 'n3',
        title: 'Baby Spinach has expired',
        body: 'Mark it as discarded to keep your inventory tidy.',
        type: NotificationType.expired,
        createdAt: now.subtract(const Duration(hours: 20)),
      ),
      NotificationModel(
        id: 'n4',
        title: 'Jamie added 3 items',
        body: 'New items were added to Dorm 4B Household.',
        type: NotificationType.household,
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
        isRead: true,
      ),
      NotificationModel(
        id: 'n5',
        title: 'Grocery reminder',
        body: 'You have 2 high-priority items on your list.',
        type: NotificationType.grocery,
        createdAt: now.subtract(const Duration(days: 2)),
        isRead: true,
      ),
    ];
  }
}
