import 'package:flutter/foundation.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/data/local/daos/household_dao.dart';
import 'package:food_expiration_reminder/data/local/daos/user_dao.dart';
import 'package:food_expiration_reminder/data/models/household_model.dart';
import 'package:food_expiration_reminder/data/models/user_model.dart';
import 'package:food_expiration_reminder/features/auth/data/auth_service.dart';

export 'package:food_expiration_reminder/features/auth/data/auth_service.dart'
    show AuthException;

/// Who is signed in and which household they act on.
///
/// The [AuthService] (Firebase) owns accounts and passwords; the local
/// profile, household and all food data stay in SQLite, keyed by the
/// account's uid.
class SessionController extends ChangeNotifier {
  SessionController({
    required this._users,
    required this._households,
    required this._auth,
  });

  final UserDao _users;
  final HouseholdDao _households;
  final AuthService _auth;

  UserModel? _user;
  bool _isRestoring = true;

  UserModel? get user => _user;
  String? get userId => _user?.id;
  String? get householdId => _user?.householdId;
  bool get isSignedIn => _user != null;

  /// True until [restore] has checked for a saved session.
  bool get isRestoring => _isRestoring;

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  /// Re-opens the account remembered on this device (works offline).
  Future<void> restore() async {
    final account = _auth.current;
    if (account != null) _user = await _localProfileFor(account);
    _isRestoring = false;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    final account = await _auth.signIn(normalizeEmail(email), password);
    _user = await _localProfileFor(account);
    notifyListeners();
  }

  /// Creates the account. With an [inviteCode] the user joins that
  /// household; otherwise they get their own, as its admin.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? inviteCode,
  }) async {
    // Check the invite code before creating anything online.
    final code = inviteCode?.trim() ?? '';
    String? joinId;
    if (code.isNotEmpty) {
      joinId = await _households.findIdByInviteCode(code);
      if (joinId == null) {
        throw const AuthException(
          'That invite code does not match any household.',
        );
      }
    }

    final account = await _auth.register(
      normalizeEmail(email),
      password,
      displayName: name.trim(),
    );
    try {
      await _createLocalProfile(account, name: name, joinHouseholdId: joinId);
    } catch (_) {
      // Never leave an online account without its local profile.
      await _auth.deleteCurrent();
      rethrow;
    }
    _user = await _users.getById(account.uid);
    notifyListeners();
  }

  /// Emails a password reset link (Firebase sends it).
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordReset(normalizeEmail(email));

  Future<void> updateProfile({String? name, String? accountType}) async {
    final updated = _user!.copyWith(name: name?.trim(), accountType: accountType);
    await _users.update(updated);
    _user = updated;
    notifyListeners();
    if (name != null) {
      // Best effort: only affects the name shown on a fresh install.
      try {
        await _auth.updateDisplayName(updated.name);
      } catch (e) {
        debugPrint('Could not sync display name: $e');
      }
    }
  }

  Future<void> changePassword(String current, String next) =>
      _auth.changePassword(current, next);

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

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }

  /// Picks up a changed household, which rebinds every data controller.
  Future<void> _reloadUser() async {
    _user = await _users.getById(_user!.id);
    notifyListeners();
  }

  /// The local profile for [account]. Accounts made on another phone (or
  /// before a reinstall) get a fresh personal kitchen on this one.
  Future<UserModel?> _localProfileFor(AuthAccount account) async {
    final existing = await _users.getById(account.uid);
    if (existing != null) return existing;
    final name = account.displayName?.trim().isNotEmpty == true
        ? account.displayName!.trim()
        : account.email.split('@').first;
    await _createLocalProfile(account, name: name);
    return _users.getById(account.uid);
  }

  Future<void> _createLocalProfile(
    AuthAccount account, {
    required String name,
    String? joinHouseholdId,
  }) async {
    final fresh = joinHouseholdId == null ? HouseholdModel.personal(name) : null;
    await _users.register(
      UserModel(
        id: account.uid,
        name: name.trim(),
        email: normalizeEmail(account.email),
        accountType: AppConstants.accountTypes.first,
      ),
      householdId: joinHouseholdId ?? fresh!.id,
      role: fresh != null ? HouseholdRole.admin : HouseholdRole.roommate,
      newHousehold: fresh,
    );
  }
}
