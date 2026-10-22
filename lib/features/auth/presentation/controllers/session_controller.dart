import 'package:flutter/foundation.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/security/password_hasher.dart';
import 'package:food_expiration_reminder/data/local/app_preferences.dart';
import 'package:food_expiration_reminder/data/local/daos/household_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/user_dao.dart';
import 'package:food_expiration_reminder/data/models/household_model.dart';
import 'package:food_expiration_reminder/data/models/user_model.dart';
import 'package:uuid/uuid.dart';

/// A failure the user can fix; [message] is shown as-is.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Who is signed in and which household they act on.
class SessionController extends ChangeNotifier {
  SessionController({
    required this._users,
    required this._households,
    required this._hasher,
    required this._prefs,
  });

  final UserDao _users;
  final HouseholdDao _households;
  final PasswordHasher _hasher;
  final AppPreferences _prefs;
  static const _uuid = Uuid();

  UserModel? _user;
  bool _isRestoring = true;

  UserModel? get user => _user;
  String? get userId => _user?.id;
  String? get householdId => _user?.householdId;
  bool get isSignedIn => _user != null;

  /// True until [restore] has checked for a saved session.
  bool get isRestoring => _isRestoring;

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  /// Re-opens the session saved on this device, if the account still exists.
  Future<void> restore() async {
    final id = _prefs.sessionUserId;
    if (id != null) {
      _user = await _users.getById(id);
      if (_user == null) await _prefs.setSessionUserId(null);
    }
    _isRestoring = false;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    const invalid = AuthException('Incorrect email or password.');
    final user = await _users.findByEmail(normalizeEmail(email));
    if (user == null) throw invalid;
    final stored = await _users.getPasswordHash(user.id);
    if (stored == null || !await _hasher.verify(password, stored)) {
      throw invalid;
    }
    await _setUser(user);
  }

  /// Creates the account. With an [inviteCode] the user joins that
  /// household; otherwise they get their own, as its admin.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? inviteCode,
  }) async {
    final normalized = normalizeEmail(email);
    if (await _users.findByEmail(normalized) != null) {
      throw const AuthException('An account with this email already exists.');
    }

    final code = inviteCode?.trim() ?? '';
    String householdId;
    HouseholdModel? newHousehold;
    if (code.isNotEmpty) {
      final found = await _households.findIdByInviteCode(code);
      if (found == null) {
        throw const AuthException('That invite code does not match any household.');
      }
      householdId = found;
    } else {
      newHousehold = HouseholdModel.personal(name);
      householdId = newHousehold.id;
    }

    final user = UserModel(
      id: _uuid.v4(),
      name: name.trim(),
      email: normalized,
      accountType: AppConstants.accountTypes.first,
    );
    await _users.register(
      user,
      passwordHash: await _hasher.hash(password),
      householdId: householdId,
      role: newHousehold != null ? HouseholdRole.admin : HouseholdRole.roommate,
      newHousehold: newHousehold,
    );
    await _setUser(await _users.getById(user.id));
  }

  Future<void> updateProfile({String? name, String? accountType}) async {
    final updated = _user!.copyWith(name: name?.trim(), accountType: accountType);
    await _users.update(updated);
    _user = updated;
    notifyListeners();
  }

  Future<void> changePassword(String current, String next) async {
    final id = _user!.id;
    final stored = await _users.getPasswordHash(id);
    if (stored == null || !await _hasher.verify(current, stored)) {
      throw const AuthException('Current password is incorrect.');
    }
    await _users.updatePasswordHash(id, await _hasher.hash(next));
  }

  /// Leaves the current household and joins the one with [inviteCode].
  Future<void> joinHousehold(String inviteCode) async {
    final user = _user!;
    final target = await _households.findIdByInviteCode(inviteCode);
    if (target == null) {
      throw const AuthException('That invite code does not match any household.');
    }
    if (target == user.householdId) {
      throw const AuthException("You're already in this household.");
    }
    await _households.moveMember(
      userId: user.id,
      fromHouseholdId: user.householdId!,
      toHouseholdId: target,
      role: HouseholdRole.roommate,
    );
    await _reloadUser();
  }

  /// Leaves the current household for a new personal one, as its admin.
  Future<void> leaveHousehold() async {
    final user = _user!;
    final fresh = HouseholdModel.personal(user.name);
    await _households.moveMember(
      userId: user.id,
      fromHouseholdId: user.householdId!,
      toHouseholdId: fresh.id,
      role: HouseholdRole.admin,
      newHousehold: fresh,
    );
    await _reloadUser();
  }

  /// Picks up a changed household, which rebinds every data controller.
  Future<void> _reloadUser() async {
    _user = await _users.getById(_user!.id);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _prefs.setSessionUserId(null);
    _user = null;
    notifyListeners();
  }

  Future<void> _setUser(UserModel? user) async {
    await _prefs.setSessionUserId(user?.id);
    _user = user;
    notifyListeners();
  }
}
