import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiration_reminder/data/local/app_preferences.dart';
import 'package:food_expiration_reminder/data/local/daos/household_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/user_dao.dart';
import 'package:food_expiration_reminder/data/local/database_helper.dart';
import 'package:food_expiration_reminder/data/local/dev_seeder.dart';
import 'package:food_expiration_reminder/data/models/household_model.dart';
import 'package:food_expiration_reminder/features/auth/presentation/controllers/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test_helpers.dart';

void main() {
  sqfliteFfiInit();

  late DatabaseHelper db;
  late AppPreferences prefs;

  SessionController newSession() => SessionController(
        users: SqfliteUserDao(db),
        households: SqfliteHouseholdDao(db),
        hasher: fastHasher,
        prefs: prefs,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await AppPreferences.load();
    db = DatabaseHelper.inMemory(databaseFactoryFfi);
    await DevSeeder.seedIfEmpty(db, fastHasher);
  });

  tearDown(() => db.close());

  test('signs in the demo account and restores it on next launch', () async {
    final session = newSession()..restore();
    await session.signIn('  Alex.Rivera@Email.com ', DevSeeder.demoPassword);
    expect(session.user!.name, 'Alex Rivera');
    expect(session.householdId, 'H-4B27');

    final relaunched = newSession();
    expect(relaunched.isRestoring, isTrue);
    await relaunched.restore();
    expect(relaunched.isRestoring, isFalse);
    expect(relaunched.userId, session.userId);

    await relaunched.signOut();
    final afterLogout = newSession();
    await afterLogout.restore();
    expect(afterLogout.isSignedIn, isFalse);
  });

  test('rejects wrong passwords, unknown emails and unusable hashes',
      () async {
    final session = newSession();
    for (final (email, pw) in [
      (DevSeeder.demoEmail, 'wrong-password'),
      ('nobody@email.com', DevSeeder.demoPassword),
      ('jamie.cruz@email.com', '!'), // seeded member without a password
    ]) {
      await expectLater(
        session.signIn(email, pw),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Incorrect email or password.',
          ),
        ),
      );
    }
    expect(session.isSignedIn, isFalse);
  });

  test('register creates a personal household with the user as admin',
      () async {
    final session = newSession();
    await session.register(
      name: 'Sam Lee',
      email: 'Sam@Email.com',
      password: 'longenough',
    );
    expect(session.user!.email, 'sam@email.com');

    final household =
        (await SqfliteHouseholdDao(db).getForUser(session.userId!))!;
    expect(household.name, "Sam's Kitchen");
    expect(household.inviteCode, matches(RegExp(r'^FRESH-[A-Z2-9]{6}$')));
    expect(household.members.single.role, HouseholdRole.admin);
    expect(session.householdId, household.id);

    await session.signOut();
    await session.signIn('sam@email.com', 'longenough');
    expect(session.isSignedIn, isTrue);
  });

  test('register with an invite code joins that household', () async {
    final session = newSession();
    await session.register(
      name: 'Kim',
      email: 'kim@email.com',
      password: 'longenough',
      inviteCode: ' fresh-4b27 ',
    );
    expect(session.householdId, 'H-4B27');
    final members =
        (await SqfliteHouseholdDao(db).getForUser(session.userId!))!.members;
    expect(members, hasLength(5));
    expect(members.last.role, HouseholdRole.roommate);
  });

  test('register rejects a taken email and a bad invite code', () async {
    final session = newSession();
    await expectLater(
      session.register(
        name: 'Alex 2',
        email: 'ALEX.RIVERA@email.com',
        password: 'longenough',
      ),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      session.register(
        name: 'Kim',
        email: 'kim@email.com',
        password: 'longenough',
        inviteCode: 'FRESH-NOPE',
      ),
      throwsA(isA<AuthException>()),
    );
    expect(await SqfliteUserDao(db).findByEmail('kim@email.com'), isNull);
  });

  test('updateProfile and changePassword persist', () async {
    final session = newSession();
    await session.signIn(DevSeeder.demoEmail, DevSeeder.demoPassword);

    await session.updateProfile(name: ' Alex R. ', accountType: 'Family');
    final stored = (await SqfliteUserDao(db).getById(session.userId!))!;
    expect(stored.name, 'Alex R.');
    expect(stored.accountType, 'Family');

    await expectLater(
      session.changePassword('not-it', 'newpassword'),
      throwsA(isA<AuthException>()),
    );
    await session.changePassword(DevSeeder.demoPassword, 'newpassword');
    await session.signOut();
    await expectLater(
      session.signIn(DevSeeder.demoEmail, DevSeeder.demoPassword),
      throwsA(isA<AuthException>()),
    );
    await session.signIn(DevSeeder.demoEmail, 'newpassword');
  });
}
