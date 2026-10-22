import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiration_reminder/data/local/app_preferences.dart';
import 'package:food_expiration_reminder/data/local/daos/food_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/household_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/user_dao.dart';
import 'package:food_expiration_reminder/data/local/database_helper.dart';
import 'package:food_expiration_reminder/data/local/dev_seeder.dart';
import 'package:food_expiration_reminder/data/models/household_model.dart';
import 'package:food_expiration_reminder/features/auth/presentation/controllers/session_controller.dart';
import 'package:food_expiration_reminder/features/household/presentation/controllers/household_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test_helpers.dart';

void main() {
  sqfliteFfiInit();

  late DatabaseHelper db;
  late SqfliteHouseholdDao households;
  late SessionController session;
  const hid = 'H-4B27';

  Future<HouseholdModel> householdOf(String userId) async =>
      (await households.getForUser(userId))!;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = DatabaseHelper.inMemory(databaseFactoryFfi);
    await DevSeeder.seedIfEmpty(db, fastHasher);
    households = SqfliteHouseholdDao(db);
    session = SessionController(
      users: SqfliteUserDao(db),
      households: households,
      hasher: fastHasher,
      prefs: await AppPreferences.load(),
    );
  });

  tearDown(() => db.close());

  group('moveMember', () {
    test('the last member leaving deletes the household and its food',
        () async {
      await session.register(
        name: 'Sam',
        email: 'sam@email.com',
        password: 'longenough',
      );
      final own = session.householdId!;
      await households.moveMember(
        userId: session.userId!,
        fromHouseholdId: own,
        toHouseholdId: hid,
        role: HouseholdRole.roommate,
      );
      expect(await households.findIdByInviteCode('FRESH-NONE'), isNull);
      final rows = await (await db.database)
          .query('households', where: 'id = ?', whereArgs: [own]);
      expect(rows, isEmpty);
      expect((await householdOf(session.userId!)).id, hid);
    });

    test('an admin leaving promotes the longest-standing member', () async {
      final fresh = HouseholdModel.personal('Alex');
      await households.moveMember(
        userId: 'u1',
        fromHouseholdId: hid,
        toHouseholdId: fresh.id,
        role: HouseholdRole.admin,
        newHousehold: fresh,
      );
      final old = await householdOf('m2');
      expect(old.members.map((m) => m.name), isNot(contains('Alex Rivera')));
      expect(old.members.first.name, 'Jamie Cruz');
      expect(old.members.first.role, HouseholdRole.admin);
      // The food stays with the remaining members.
      expect(await SqfliteFoodDao(db).getAll(hid), isNotEmpty);
    });
  });

  group('SessionController', () {
    setUp(() => session.register(
          name: 'Kim Reyes',
          email: 'kim@email.com',
          password: 'longenough',
        ));

    test('joinHousehold validates the code', () async {
      await expectLater(
        session.joinHousehold('FRESH-NOPE'),
        throwsA(isA<AuthException>()),
      );
      final own = (await householdOf(session.userId!)).inviteCode;
      await expectLater(
        session.joinHousehold(own.toLowerCase()),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            "You're already in this household.",
          ),
        ),
      );
    });

    test('join then leave moves the session between households', () async {
      await session.joinHousehold(' fresh-4b27 ');
      expect(session.householdId, hid);
      final joined = await householdOf(session.userId!);
      expect(joined.members.last.name, 'Kim Reyes');
      expect(joined.members.last.role, HouseholdRole.roommate);
      expect(joined.canManage, isFalse);

      await session.leaveHousehold();
      expect(session.householdId, isNot(hid));
      final mine = await householdOf(session.userId!);
      expect(mine.name, "Kim's Kitchen");
      expect(mine.canManage, isTrue);
      expect((await householdOf('u1')).members, hasLength(4));
    });
  });

  group('HouseholdController (admin)', () {
    late HouseholdController controller;

    setUp(() async {
      controller = HouseholdController(households)..bind('u1');
      await controller.refresh();
    });

    test('rename and a new invite code', () async {
      final oldCode = controller.household!.inviteCode;
      await controller.rename('  Dorm 4B  ');
      await controller.regenerateInviteCode();
      expect(controller.household!.name, 'Dorm 4B');
      expect(controller.household!.inviteCode, isNot(oldCode));
      expect(await households.findIdByInviteCode(oldCode), isNull);
      expect(
        await households.findIdByInviteCode(controller.household!.inviteCode),
        hid,
      );
    });

    test('change a role and remove a member', () async {
      final jamie = controller.household!.members[1];
      await controller.setRole(jamie, HouseholdRole.familyMember);
      expect(controller.household!.members[1].role, HouseholdRole.familyMember);

      await controller.removeMember(controller.household!.members[1]);
      expect(controller.household!.members, hasLength(3));
      final theirs = await householdOf(jamie.id);
      expect(theirs.name, "Jamie's Kitchen");
      expect(theirs.members.single.role, HouseholdRole.admin);
    });
  });
}
