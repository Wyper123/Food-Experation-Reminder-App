import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiration_reminder/data/local/daos/household_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/user_dao.dart';
import 'package:food_expiration_reminder/data/local/database_helper.dart';
import 'package:food_expiration_reminder/data/local/dev_seeder.dart';
import 'package:food_expiration_reminder/data/models/household_model.dart';
import 'package:food_expiration_reminder/features/auth/data/auth_service.dart';
import 'package:food_expiration_reminder/features/auth/presentation/controllers/session_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test_helpers.dart';

void main() {
  sqfliteFfiInit();

  late DatabaseHelper db;
  late FakeAuthService auth;

  SessionController newSession() => SessionController(
        users: SqfliteUserDao(db),
        households: SqfliteHouseholdDao(db),
        auth: auth,
      );

  setUp(() async {
    auth = FakeAuthService.withDemo();
    db = DatabaseHelper.inMemory(databaseFactoryFfi);
    await DevSeeder.seedIfEmpty(db);
  });

  tearDown(() => db.close());

  test('signs in the demo account and restores it on next launch', () async {
    final session = newSession()..restore();
    await session.signIn('  Alex.Rivera@Email.com ', DevSeeder.demoPassword);
    expect(session.user!.name, 'Alex Rivera');
    expect(session.householdId, 'H-4B27');

    // The auth provider remembers the account across launches.
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

  test('wrong password or unknown email is rejected', () async {
    final session = newSession();
    for (final (email, pw) in [
      (DevSeeder.demoEmail, 'wrong-password'),
      ('nobody@email.com', DevSeeder.demoPassword),
    ]) {
      await expectLater(
        session.signIn(email, pw),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            AuthException.badCredentials.message,
          ),
        ),
      );
    }
    expect(session.isSignedIn, isFalse);
  });

  test('register creates the account and a personal household', () async {
    final session = newSession();
    await session.register(
      name: 'Sam Lee',
      email: 'Sam@Email.com',
      password: 'longenough',
    );
    expect(auth.hasAccount('sam@email.com'), isTrue);
    // The local profile is keyed by the auth provider's uid.
    expect(session.userId, auth.current!.uid);
    expect(session.user!.email, 'sam@email.com');

    final household =
        (await SqfliteHouseholdDao(db).getForUser(session.userId!))!;
    expect(household.name, "Sam's Kitchen");
    expect(household.members.single.role, HouseholdRole.admin);
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

  test('a bad invite code fails before any account is created', () async {
    await expectLater(
      newSession().register(
        name: 'Kim',
        email: 'kim@email.com',
        password: 'longenough',
        inviteCode: 'FRESH-NOPE',
      ),
      throwsA(isA<AuthException>()),
    );
    expect(auth.hasAccount('kim@email.com'), isFalse);
  });

  test('a failed local profile rolls back the online account', () async {
    // This phone already has a local profile with that email (a seeded
    // member with no online account), so the local insert fails after the
    // online account was created.
    final session = newSession();
    await expectLater(
      session.register(
        name: 'Dup',
        email: 'jamie.cruz@email.com',
        password: 'longenough',
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(auth.hasAccount('jamie.cruz@email.com'), isFalse);
    expect(session.isSignedIn, isFalse);
  });

  test('an account from another phone gets a fresh local kitchen', () async {
    // Exists online, but this phone's database has never seen it.
    await auth.register('mia@email.com', 'longenough', displayName: 'Mia Cruz');
    await auth.signOut();

    final session = newSession();
    await session.signIn('mia@email.com', 'longenough');
    expect(session.user!.name, 'Mia Cruz');
    final household =
        (await SqfliteHouseholdDao(db).getForUser(session.userId!))!;
    expect(household.name, "Mia's Kitchen");
  });

  test('password reset is sent for the normalised email', () async {
    await newSession().sendPasswordReset('  Alex.Rivera@Email.com ');
    expect(auth.resetEmails, [DevSeeder.demoEmail]);
  });

  test('change password checks the current one', () async {
    final session = newSession();
    await session.signIn(DevSeeder.demoEmail, DevSeeder.demoPassword);
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

  test('profile edits save locally', () async {
    final session = newSession();
    await session.signIn(DevSeeder.demoEmail, DevSeeder.demoPassword);
    await session.updateProfile(name: ' Alex R. ', accountType: 'Family');
    final stored = (await SqfliteUserDao(db).getById(session.userId!))!;
    expect(stored.name, 'Alex R.');
    expect(stored.accountType, 'Family');
  });

  test('Google sign-in creates a profile once and reuses it', () async {
    auth.nextGoogleAccount = const AuthAccount(
      uid: 'google-1',
      email: 'gian@gmail.com',
      displayName: 'Gian Coronel',
    );
    final session = newSession();
    expect(await session.signInWithGoogle(), isTrue);
    expect(session.user!.name, 'Gian Coronel');
    final kitchen = (await SqfliteHouseholdDao(db).getForUser('google-1'))!;
    expect(kitchen.name, "Gian's Kitchen");

    // Second sign-in: same local profile and kitchen, nothing duplicated.
    await session.signOut();
    expect(await session.signInWithGoogle(), isTrue);
    expect(
      (await SqfliteHouseholdDao(db).getForUser('google-1'))!.id,
      kitchen.id,
    );
  });

  test('backing out of the Google picker signs nobody in', () async {
    final session = newSession();
    expect(await session.signInWithGoogle(), isFalse);
    expect(session.isSignedIn, isFalse);
  });
}
