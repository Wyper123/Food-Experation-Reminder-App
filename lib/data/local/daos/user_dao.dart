import 'package:food_expiration_reminder/data/local/database_helper.dart';
import 'package:food_expiration_reminder/data/models/household_model.dart';
import 'package:food_expiration_reminder/data/models/user_model.dart';

/// User account persistence. Password hashing happens before this layer.
abstract class UserDao {
  Future<UserModel?> getById(String id);
  Future<UserModel?> findByEmail(String email);
  Future<String?> getPasswordHash(String userId);

  /// Creates the user and their household membership atomically.
  /// Pass [newHousehold] to create it first (the user becomes its admin);
  /// otherwise the user joins the existing [householdId].
  Future<void> register(
    UserModel user, {
    required String passwordHash,
    required String householdId,
    required HouseholdRole role,
    HouseholdModel? newHousehold,
  });

  Future<void> update(UserModel user);
  Future<void> updatePasswordHash(String userId, String passwordHash);
}

class SqfliteUserDao implements UserDao {
  SqfliteUserDao(this._helper);

  final DatabaseHelper _helper;

  // Users without a household get NULL household_id from the LEFT JOIN.
  static const _select =
      'SELECT u.id, u.name, u.email, u.account_type, m.household_id '
      'FROM users u LEFT JOIN household_members m ON m.user_id = u.id ';

  @override
  Future<UserModel?> getById(String id) async {
    final db = await _helper.database;
    final rows = await db.rawQuery('${_select}WHERE u.id = ? LIMIT 1', [id]);
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  @override
  Future<UserModel?> findByEmail(String email) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      '${_select}WHERE u.email = ? LIMIT 1',
      [email.trim()],
    );
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  @override
  Future<String?> getPasswordHash(String userId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'users',
      columns: ['password_hash'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['password_hash']! as String;
  }

  @override
  Future<void> register(
    UserModel user, {
    required String passwordHash,
    required String householdId,
    required HouseholdRole role,
    HouseholdModel? newHousehold,
  }) async {
    final db = await _helper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      if (newHousehold != null) {
        await txn.insert('households', {
          ...newHousehold.toMap(),
          'created_at': now,
        });
      }
      await txn.insert('users', {
        ...user.toMap(),
        'password_hash': passwordHash,
        'created_at': now,
      });
      // New members get the next avatar colour in the household.
      final count = (await txn.rawQuery(
        'SELECT COUNT(*) AS c FROM household_members WHERE household_id = ?',
        [householdId],
      ))
          .first['c']! as int;
      await txn.insert('household_members', {
        'household_id': householdId,
        'user_id': user.id,
        'role': role.name,
        'color_index': count,
        'joined_at': now,
      });
    });
  }

  @override
  Future<void> update(UserModel user) async {
    final db = await _helper.database;
    await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  @override
  Future<void> updatePasswordHash(String userId, String passwordHash) async {
    final db = await _helper.database;
    await db.update(
      'users',
      {'password_hash': passwordHash},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}
