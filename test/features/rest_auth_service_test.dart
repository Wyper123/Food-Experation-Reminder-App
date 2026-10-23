import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiration_reminder/data/local/app_preferences.dart';
import 'package:food_expiration_reminder/features/auth/data/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A scripted Firebase: records calls and answers from [replies].
class FakeFirebase {
  final calls = <(String, Map<String, Object?>)>[];
  final replies = <String, Object Function(Map<String, Object?>)>{};

  Future<Map<String, dynamic>> post(
    String method,
    Map<String, Object?> body,
  ) async {
    calls.add((method, body));
    final reply = replies[method]?.call(body) ?? <String, dynamic>{};
    if (reply is Exception) throw reply;
    if (reply is Future<Map<String, dynamic>>) return reply;
    return reply as Map<String, dynamic>;
  }

  List<String> get methods => [for (final (m, _) in calls) m];
}

void main() {
  late AppPreferences prefs;
  late FakeFirebase firebase;
  late FirebaseRestAuthService auth;

  Map<String, dynamic> session(String email, {String? name}) => {
        'localId': 'uid-$email',
        'email': email,
        'idToken': 'token-$email',
        'displayName': ?name,
      };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await AppPreferences.load();
    firebase = FakeFirebase();
    auth = FirebaseRestAuthService(
      prefs: prefs,
      apiKey: 'test-key',
      post: firebase.post,
    );
  });

  test('sign in remembers the account across launches', () async {
    firebase.replies['accounts:signInWithPassword'] =
        (b) => session(b['email']! as String, name: 'Gian');
    final account = await auth.signIn('gian@gmail.com', 'secret12');
    expect(account.uid, 'uid-gian@gmail.com');

    final relaunched = FirebaseRestAuthService(
      prefs: prefs,
      apiKey: 'test-key',
      post: firebase.post,
    );
    expect(relaunched.current?.email, 'gian@gmail.com');
    expect(relaunched.current?.displayName, 'Gian');

    await relaunched.signOut();
    expect(auth.current, isNull);
  });

  test('Firebase error codes become readable messages', () async {
    for (final (code, message) in [
      ('INVALID_LOGIN_CREDENTIALS', AuthException.badCredentials.message),
      ('EMAIL_EXISTS', 'An account with this email already exists.'),
      ('WEAK_PASSWORD', 'Choose a stronger password.'),
      ('TOO_MANY_ATTEMPTS_TRY_LATER',
          'Too many attempts. Wait a few minutes and try again.'),
    ]) {
      firebase.replies['accounts:signInWithPassword'] =
          (_) => FirebaseRestError(code);
      await expectLater(
        auth.signIn('a@b.co', 'x'),
        throwsA(isA<AuthException>().having((e) => e.message, code, message)),
      );
    }
  });

  test('no network gives a clear message', () async {
    firebase.replies['accounts:signInWithPassword'] =
        (_) => const SocketException('no route');
    await expectLater(
      auth.signIn('a@b.co', 'x'),
      throwsA(isA<AuthException>()
          .having((e) => e.message, 'message', contains('No internet'))),
    );
  });

  test('register sets the display name and remembers the account', () async {
    firebase.replies['accounts:signUp'] = (b) => session(b['email']! as String);
    final account =
        await auth.register('sam@email.com', 'longenough', displayName: 'Sam');
    expect(firebase.methods, ['accounts:signUp', 'accounts:update']);
    expect(firebase.calls.last.$2['displayName'], 'Sam');
    expect(account.displayName, 'Sam');
    expect(auth.current?.displayName, 'Sam');
  });

  test('rolling back a signup deletes the new account', () async {
    firebase.replies['accounts:signUp'] = (b) => session(b['email']! as String);
    await auth.register('sam@email.com', 'longenough', displayName: 'Sam');
    await auth.deleteCurrent();
    expect(firebase.methods.last, 'accounts:delete');
    expect(firebase.calls.last.$2['idToken'], 'token-sam@email.com');
    expect(auth.current, isNull);
  });

  test('reset email: sent, and unknown emails look the same', () async {
    await auth.sendPasswordReset('gian@gmail.com');
    expect(firebase.calls.single.$2, {
      'requestType': 'PASSWORD_RESET',
      'email': 'gian@gmail.com',
    });

    firebase.replies['accounts:sendOobCode'] =
        (_) => const FirebaseRestError('EMAIL_NOT_FOUND');
    await auth.sendPasswordReset('nobody@email.com'); // no error
  });

  test('change password re-checks the current one first', () async {
    firebase.replies['accounts:signInWithPassword'] = (b) =>
        b['password'] == 'old-pass'
            ? session(b['email']! as String)
            : const FirebaseRestError('INVALID_LOGIN_CREDENTIALS');
    await auth.signIn('gian@gmail.com', 'old-pass');

    await expectLater(
      auth.changePassword('wrong', 'new-pass'),
      throwsA(isA<AuthException>().having(
        (e) => e.message,
        'message',
        'Current password is incorrect.',
      )),
    );
    await auth.changePassword('old-pass', 'new-pass');
    expect(firebase.methods.last, 'accounts:update');
    expect(firebase.calls.last.$2['password'], 'new-pass');
  });
}

