import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// A failure the user can fix; [message] is shown as-is.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The signed-in account as the auth provider knows it. Profile details
/// and all food data live locally, keyed by [uid].
class AuthAccount {
  const AuthAccount({required this.uid, required this.email, this.displayName});

  final String uid;
  final String email;
  final String? displayName;
}

/// Accounts and passwords. The app depends on this interface so tests can
/// run offline with a fake.
abstract class AuthService {
  /// Restored from the device on launch; works offline once signed in.
  AuthAccount? get current;

  Future<AuthAccount> signIn(String email, String password);
  Future<AuthAccount> register(
    String email,
    String password, {
    required String displayName,
  });

  /// Shows the phone's Google account picker and signs in with the chosen
  /// account (creating it on first use). Null when the user backs out.
  Future<AuthAccount?> signInWithGoogle();

  /// Removes the just-created account (used to roll back a failed signup).
  Future<void> deleteCurrent();

  /// Emails a reset link. Completes normally even for unknown addresses so
  /// the app never reveals which emails have accounts.
  Future<void> sendPasswordReset(String email);

  Future<void> changePassword(String current, String next);
  Future<void> updateDisplayName(String name);
  Future<void> signOut();
}

/// Firebase Authentication: passwords never touch this device's storage,
/// and reset emails are sent by Firebase.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService([FirebaseAuth? auth])
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static AuthAccount _account(User u) =>
      AuthAccount(uid: u.uid, email: u.email ?? '', displayName: u.displayName);

  @override
  AuthAccount? get current {
    final u = _auth.currentUser;
    return u == null ? null : _account(u);
  }

  @override
  Future<AuthAccount> signIn(String email, String password) => _guard(() async {
        final cred = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return _account(cred.user!);
      });

  @override
  Future<AuthAccount> register(
    String email,
    String password, {
    required String displayName,
  }) =>
      _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = cred.user!;
        // Lets a fresh install on another phone show the right name.
        await user.updateDisplayName(displayName);
        return AuthAccount(
          uid: user.uid,
          email: user.email ?? email,
          displayName: displayName,
        );
      });

  bool _googleReady = false;

  @override
  Future<AuthAccount?> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    final GoogleSignInAccount picked;
    try {
      if (!_googleReady) {
        // Client ids come from google-services.json.
        await google.initialize();
        _googleReady = true;
      }
      // Not timed: the user may take a while to choose an account.
      picked = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw AuthException(
        'Google sign-in is unavailable right now (${e.code.name}). '
        'Use email and password instead.',
      );
    }
    final idToken = picked.authentication.idToken;
    return _guard(() async {
      final cred = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return _account(cred.user!);
    });
  }

  @override
  Future<void> deleteCurrent() async => _auth.currentUser?.delete();

  @override
  Future<void> sendPasswordReset(String email) => _guard(() async {
        try {
          await _auth.sendPasswordResetEmail(email: email);
        } on FirebaseAuthException catch (e) {
          // Same outcome as success, so emails cannot be probed.
          if (e.code != 'user-not-found') rethrow;
        }
      });

  @override
  Future<void> changePassword(String current, String next) => _guard(() async {
        final user = _auth.currentUser!;
        if (!user.providerData.any((p) => p.providerId == 'password')) {
          throw const AuthException(
            "You sign in with Google, so there's no app password to change. "
            'Manage your password in your Google account.',
          );
        }
        try {
          // Firebase requires a recent sign-in before a password change.
          await user.reauthenticateWithCredential(
            EmailAuthProvider.credential(email: user.email!, password: current),
          );
        } on FirebaseAuthException catch (e) {
          if (const {'wrong-password', 'invalid-credential'}.contains(e.code)) {
            throw const AuthException('Current password is incorrect.');
          }
          rethrow;
        }
        await user.updatePassword(next);
      });

  @override
  Future<void> updateDisplayName(String name) async =>
      _auth.currentUser?.updateDisplayName(name);

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    // So the next Google sign-in asks which account to use.
    if (_googleReady) await GoogleSignIn.instance.signOut();
  }

  /// Longest a login request may take before the user is told to check the
  /// connection. Firebase itself can wait minutes, e.g. on Wi-Fi with
  /// broken IPv6, which left the button spinning.
  static const requestTimeout = Duration(seconds: 20);

  /// Turns Firebase's error codes into messages a user can act on.
  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(requestTimeout);
    } on TimeoutException {
      throw const AuthException(
        "Couldn't reach the login server. Check your internet; if you're on "
        'Wi-Fi, try mobile data.',
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(switch (e.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'Incorrect email or password.',
        'invalid-email' => 'Enter a valid email address.',
        'email-already-in-use' => 'An account with this email already exists.',
        'weak-password' => 'Choose a stronger password.',
        'user-disabled' => 'This account has been disabled.',
        'network-request-failed' =>
          'No internet connection. Connect and try again.',
        'too-many-requests' =>
          'Too many attempts. Wait a few minutes and try again.',
        'requires-recent-login' => 'Please log out and log in again first.',
        'operation-not-allowed' =>
          'Email sign-in is turned off for this app (Firebase settings).',
        _ => 'Something went wrong (${e.code}). Please try again.',
      });
    }
  }
}
