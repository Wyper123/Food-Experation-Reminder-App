import 'package:food_expiration_reminder/data/local/database_helper.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:food_expiration_reminder/data/models/grocery_item_model.dart';
import 'package:food_expiration_reminder/data/models/household_model.dart';
import 'package:food_expiration_reminder/data/models/notification_model.dart';
import 'package:food_expiration_reminder/data/models/user_model.dart';

/// Fills an empty database with a demo household, used by tests. Accounts
/// live in Firebase, so the demo login ([demoEmail] / [demoPassword]) only
/// exists in the tests' fake auth service, as uid [UserModel.mock]'s id.
class DevSeeder {
  DevSeeder._();

  static const String demoEmail = 'alex.rivera@email.com';
  static const String demoPassword = 'demo1234';

  static Future<void> seedIfEmpty(DatabaseHelper helper) async {
    final db = await helper.database;
    final count = (await db.rawQuery('SELECT COUNT(*) AS c FROM users'))
        .first['c']! as int;
    if (count > 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    const household = HouseholdModel.mock;

    await db.transaction((txn) async {
      final batch = txn.batch()
        ..insert('households', {...household.toMap(), 'created_at': now});

      for (final (i, m) in household.members.indexed) {
        final user = m.isCurrentUser
            ? UserModel.mock
            : UserModel(
                id: m.id,
                name: m.name,
                email: '${m.name.toLowerCase().replaceAll(' ', '.')}@email.com',
                accountType: 'Student',
              );
        batch
          ..insert('users', {
            ...user.toMap(),
            'password_hash': '',
            'created_at': now,
          })
          ..insert('household_members', {
            'household_id': household.id,
            'user_id': user.id,
            'role': m.role.name,
            'color_index': m.colorIndex,
            // Keeps the original member order.
            'joined_at': now + i,
          });
      }

      for (final f in FoodItemModel.mockList) {
        batch.insert('food_items', f.toMap(householdId: household.id));
      }
      for (final (i, g) in GroceryItemModel.mockList.indexed) {
        batch.insert('grocery_items', {
          ...g.toMap(householdId: household.id),
          'created_at': now + i,
        });
      }
      for (final n in NotificationModel.mockList) {
        batch.insert('notifications', n.toMap(householdId: household.id));
      }
      await batch.commit(noResult: true);
    });
  }
}
