import 'package:food_expiration_reminder/data/local/dev_seeder.dart';
import 'package:food_expiration_reminder/data/models/user_model.dart';
import 'package:food_expiration_reminder/features/auth/data/auth_service.dart';

/// In-memory stand-in for Firebase Authentication, so tests run offline.
/// Mirrors the real service's messages and behaviour.
class FakeAuthService implements AuthService {
  FakeAuthService();

  /// Knows the seeded demo account (uid matches [DevSeeder]'s demo user).
  factory FakeAuthService.withDemo() => FakeAuthService()
    .._accounts[DevSeeder.demoEmail] = (
      uid: UserModel.mock.id,
      password: DevSeeder.demoPassword,
      name: UserModel.mock.name,
    );

  final _accounts = <String, ({String uid, String password, String? name})>{};
  AuthAccount? _current;
  int _nextId = 1;

  /// Every address a reset link was "sent" to.
  final resetEmails = <String>[];

  bool hasAccount(String email) => _accounts.containsKey(email);

  AuthAccount _account(String email) {
    final a = _accounts[email]!;
    return AuthAccount(uid: a.uid, email: email, displayName: a.name);
  }

  @override
  AuthAccount? get current => _current;

  @override
  Future<AuthAccount> signIn(String email, String password) async {
    final a = _accounts[email];
    if (a == null || a.password != password) {
      throw const AuthException('Incorrect email or password.');
    }
    return _current = _account(email);
  }

  @override
  Future<AuthAccount> register(
    String email,
    String password, {
    required String displayName,
  }) async {
    if (_accounts.containsKey(email)) {
      throw const AuthException('An account with this email already exists.');
    }
    _accounts[email] =
        (uid: 'fb-${_nextId++}', password: password, name: displayName);
    return _current = _account(email);
  }

  /// What the Google account picker returns next; null = the user backed out.
  AuthAccount? nextGoogleAccount;

  @override
  Future<AuthAccount?> signInWithGoogle() async {
    final picked = nextGoogleAccount;
    if (picked == null) return null;
    // First use creates the account, like Firebase does.
    _accounts.putIfAbsent(
      picked.email,
      () => (uid: picked.uid, password: '', name: picked.displayName),
    );
    return _current = picked;
  }

  @override
  Future<void> deleteCurrent() async {
    final c = _current;
    if (c != null) _accounts.remove(c.email);
    _current = null;
  }

  @override
  Future<void> sendPasswordReset(String email) async => resetEmails.add(email);

  @override
  Future<void> changePassword(String current, String next) async {
    final email = _current!.email;
    final a = _accounts[email]!;
    if (a.password != current) {
      throw const AuthException('Current password is incorrect.');
    }
    _accounts[email] = (uid: a.uid, password: next, name: a.name);
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final email = _current!.email;
    final a = _accounts[email]!;
    _accounts[email] = (uid: a.uid, password: a.password, name: name);
  }

  @override
  Future<void> signOut() async => _current = null;
}
