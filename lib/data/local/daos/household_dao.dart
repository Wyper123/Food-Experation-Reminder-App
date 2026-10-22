import 'package:food_expiration_reminder/data/local/database_helper.dart';
import 'package:food_expiration_reminder/data/models/household_model.dart';

/// Household / shared inventory persistence.
abstract class HouseholdDao {
  /// The household [userId] belongs to, with all members loaded.
  Future<HouseholdModel?> getForUser(String userId);
  Future<String?> findIdByInviteCode(String code);

  /// Moves [userId] from [fromHouseholdId] into [toHouseholdId] as [role],
  /// creating [newHousehold] first when given. In one transaction it also
  /// tidies the old household: deleted (with its food) if nobody is left,
  /// otherwise its longest-standing member becomes admin if none remains.
  Future<void> moveMember({
    required String userId,
    required String fromHouseholdId,
    required String toHouseholdId,
    required HouseholdRole role,
    HouseholdModel? newHousehold,
  });

  Future<void> updateMemberRole(
    String householdId,
    String userId,
    HouseholdRole role,
  );
  Future<void> rename(String householdId, String name);
  Future<void> setInviteCode(String householdId, String code);
}

class SqfliteHouseholdDao implements HouseholdDao {
  SqfliteHouseholdDao(this._helper);

  final DatabaseHelper _helper;

  @override
  Future<HouseholdModel?> getForUser(String userId) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT h.* FROM households h '
      'JOIN household_members m ON m.household_id = h.id '
      'WHERE m.user_id = ? LIMIT 1',
      [userId],
    );
    if (rows.isEmpty) return null;

    final memberRows = await db.rawQuery(
      'SELECT m.user_id, m.role, m.color_index, u.name '
      'FROM household_members m JOIN users u ON u.id = m.user_id '
      'WHERE m.household_id = ? ORDER BY m.joined_at ASC',
      [rows.first['id']],
    );
    return HouseholdModel.fromMap(
      rows.first,
      members: [
        for (final r in memberRows)
          HouseholdMember.fromMap(r, currentUserId: userId),
      ],
    );
  }

  @override
  Future<String?> findIdByInviteCode(String code) async {
    final db = await _helper.database;
    final rows = await db.query(
      'households',
      columns: ['id'],
      where: 'invite_code = ?',
      whereArgs: [code.trim().toUpperCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id']! as String;
  }

  @override
  Future<void> moveMember({
    required String userId,
    required String fromHouseholdId,
    required String toHouseholdId,
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
      await txn.delete(
        'household_members',
        where: 'household_id = ? AND user_id = ?',
        whereArgs: [fromHouseholdId, userId],
      );

      final left = await txn.query(
        'household_members',
        where: 'household_id = ?',
        whereArgs: [fromHouseholdId],
        orderBy: 'joined_at ASC',
      );
      if (left.isEmpty) {
        // Cascades to its food, groceries and notifications.
        await txn.delete(
          'households',
          where: 'id = ?',
          whereArgs: [fromHouseholdId],
        );
      } else if (!left.any((m) => m['role'] == HouseholdRole.admin.name)) {
        await txn.update(
          'household_members',
          {'role': HouseholdRole.admin.name},
          where: 'household_id = ? AND user_id = ?',
          whereArgs: [fromHouseholdId, left.first['user_id']],
        );
      }

      final count = (await txn.rawQuery(
        'SELECT COUNT(*) AS c FROM household_members WHERE household_id = ?',
        [toHouseholdId],
      ))
          .first['c']! as int;
      await txn.insert('household_members', {
        'household_id': toHouseholdId,
        'user_id': userId,
        'role': role.name,
        'color_index': count,
        'joined_at': now,
      });
    });
  }

  @override
  Future<void> updateMemberRole(
    String householdId,
    String userId,
    HouseholdRole role,
  ) async {
    final db = await _helper.database;
    await db.update(
      'household_members',
      {'role': role.name},
      where: 'household_id = ? AND user_id = ?',
      whereArgs: [householdId, userId],
    );
  }

  @override
  Future<void> rename(String householdId, String name) async {
    final db = await _helper.database;
    await db.update(
      'households',
      {'name': name.trim()},
      where: 'id = ?',
      whereArgs: [householdId],
    );
  }

  @override
  Future<void> setInviteCode(String householdId, String code) async {
    final db = await _helper.database;
    await db.update(
      'households',
      {'invite_code': code},
      where: 'id = ?',
      whereArgs: [householdId],
    );
  }
}
