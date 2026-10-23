import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:food_expiration_reminder/data/local/app_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// A failure the user can fix; [message] is shown as-is.
class AuthException implements Exception {
  const AuthException(this.message);

  /// Wrong email or password. Firebase cannot say which (that would reveal
  /// which emails have accounts), so this also points Google users, who
  /// have no app password, to the right button.
  static const badCredentials = AuthException(
    'Incorrect email or password. If you signed up with Google, use '
    'Continue with Google.',
  );

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

/// Sends one Firebase Auth REST request ([method] such as
/// "accounts:signInWithPassword") and returns the JSON reply. Throws
/// [FirebaseRestError] for error replies. Replaceable in tests.
typedef FirebaseAuthPost = Future<Map<String, dynamic>> Function(
  String method,
  Map<String, Object?> body,
);

/// An error reply from Firebase, e.g. code "EMAIL_EXISTS".
class FirebaseRestError implements Exception {
  const FirebaseRestError(this.code);

  final String code;

  @override
  String toString() => 'FirebaseRestError($code)';
}

/// Firebase Authentication through its official REST API.
///
/// The Firebase Android SDK hung for minutes on Wi-Fi with broken IPv6;
/// Dart's own HTTP client falls back to IPv4 like a browser does, so login
/// works on such networks. Passwords never touch this device's storage.
class FirebaseRestAuthService implements AuthService {
  FirebaseRestAuthService({
    required this._prefs,
    required String apiKey,
    FirebaseAuthPost? post,
  }) : _post = post ?? _httpPost(apiKey);

  final AppPreferences _prefs;
  final FirebaseAuthPost _post;

  /// Longest a request may take before the user is told to check the
  /// connection.
  static const requestTimeout = Duration(seconds: 20);

  /// Token from the latest sign-in; only needed briefly (rollback, name).
  String? _idToken;
  bool _googleReady = false;

  static const _password = 'password';
  static const _google = 'google.com';

  @override
  AuthAccount? get current {
    final raw = _prefs.authAccountJson;
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return AuthAccount(
      uid: m['uid'] as String,
      email: m['email'] as String,
      displayName: m['name'] as String?,
    );
  }

  String? get _currentProvider {
    final raw = _prefs.authAccountJson;
    return raw == null ? null : (jsonDecode(raw) as Map)['provider'] as String?;
  }

  @override
  Future<AuthAccount> signIn(String email, String password) async {
    final r = await _call('accounts:signInWithPassword', {
      'email': email,
      'password': password,
      'returnSecureToken': true,
    });
    return _remember(r, provider: _password);
  }

  @override
  Future<AuthAccount> register(
    String email,
    String password, {
    required String displayName,
  }) async {
    final r = await _call('accounts:signUp', {
      'email': email,
      'password': password,
      'returnSecureToken': true,
    });
    _idToken = r['idToken'] as String?;
    // Lets a fresh install on another phone show the right name.
    await _call('accounts:update', {
      'idToken': _idToken,
      'displayName': displayName,
      'returnSecureToken': false,
    });
    return _remember({...r, 'displayName': displayName}, provider: _password);
  }

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
    final r = await _call('accounts:signInWithIdp', {
      'postBody':
          'id_token=${picked.authentication.idToken}&providerId=$_google',
      'requestUri': 'http://localhost',
      'returnSecureToken': true,
    });
    return _remember(r, provider: _google);
  }

  @override
  Future<void> deleteCurrent() async {
    final token = _idToken;
    if (token != null) await _call('accounts:delete', {'idToken': token});
    await signOut();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _call(
          'accounts:sendOobCode',
          {
            'requestType': 'PASSWORD_RESET',
            'email': email,
          },
          raw: true);
    } on FirebaseRestError catch (e) {
      // Same outcome as success, so emails cannot be probed.
      if (e.code != 'EMAIL_NOT_FOUND') throw _message(e.code);
    }
  }

  @override
  Future<void> changePassword(String current, String next) async {
    final account = this.current!;
    if (_currentProvider == _google) {
      throw const AuthException(
        "You sign in with Google, so there's no app password to change. "
        'Manage your password in your Google account.',
      );
    }
    final Map<String, dynamic> r;
    try {
      // Re-checking the current password also yields a fresh token.
      r = await _call(
          'accounts:signInWithPassword',
          {
            'email': account.email,
            'password': current,
            'returnSecureToken': true,
          },
          raw: true);
    } on FirebaseRestError catch (e) {
      if (_isBadCredentials(e.code)) {
        throw const AuthException('Current password is incorrect.');
      }
      throw _message(e.code);
    }
    await _call('accounts:update', {
      'idToken': r['idToken'],
      'password': next,
      'returnSecureToken': false,
    });
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final token = _idToken;
    // Best effort: only possible shortly after signing in on this device.
    if (token == null) return;
    await _call('accounts:update', {
      'idToken': token,
      'displayName': name,
      'returnSecureToken': false,
    });
  }

  @override
  Future<void> signOut() async {
    _idToken = null;
    await _prefs.setAuthAccountJson(null);
    // So the next Google sign-in asks which account to use.
    if (_googleReady) await GoogleSignIn.instance.signOut();
  }

  Future<AuthAccount> _remember(
    Map<String, dynamic> r, {
    required String provider,
  }) async {
    _idToken = r['idToken'] as String?;
    final name = (r['displayName'] as String?)?.trim();
    final account = AuthAccount(
      uid: r['localId'] as String,
      email: r['email'] as String,
      displayName: name == null || name.isEmpty ? null : name,
    );
    await _prefs.setAuthAccountJson(jsonEncode({
      'uid': account.uid,
      'email': account.email,
      'name': account.displayName,
      'provider': provider,
    }));
    return account;
  }

  /// One request with the timeout and readable errors. With [raw], Firebase
  /// error codes are rethrown for the caller to interpret.
  Future<Map<String, dynamic>> _call(
    String method,
    Map<String, Object?> body, {
    bool raw = false,
  }) async {
    try {
      return await _post(method, body).timeout(requestTimeout);
    } on FirebaseRestError catch (e) {
      if (raw) rethrow;
      throw _message(e.code);
    } on TimeoutException {
      throw const AuthException(
        "Couldn't reach the login server. Check your internet and try "
        'again.',
      );
    } on IOException {
      throw const AuthException(
        'No internet connection. Connect and try again.',
      );
    }
  }

  static bool _isBadCredentials(String code) => const {
        'INVALID_LOGIN_CREDENTIALS',
        'INVALID_PASSWORD',
        'EMAIL_NOT_FOUND',
      }.contains(code);

  /// Firebase's error codes as messages a user can act on.
  static AuthException _message(String code) {
    if (_isBadCredentials(code)) return AuthException.badCredentials;
    return AuthException(switch (code) {
      'INVALID_EMAIL' => 'Enter a valid email address.',
      'EMAIL_EXISTS' => 'An account with this email already exists.',
      'WEAK_PASSWORD' => 'Choose a stronger password.',
      'USER_DISABLED' => 'This account has been disabled.',
      'TOO_MANY_ATTEMPTS_TRY_LATER' =>
        'Too many attempts. Wait a few minutes and try again.',
      'OPERATION_NOT_ALLOWED' =>
        'This sign-in method is turned off for this app (Firebase settings).',
      'INVALID_IDP_RESPONSE' => 'Google sign-in failed. Please try again.',
      _ => 'Something went wrong ($code). Please try again.',
    });
  }

  static FirebaseAuthPost _httpPost(String apiKey) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    return (method, body) async {
      final uri = Uri.https(
        'identitytoolkit.googleapis.com',
        '/v1/$method',
        {'key': apiKey},
      );
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      final json = (text.isEmpty ? <String, dynamic>{} : jsonDecode(text))
          as Map<String, dynamic>;
      if (response.statusCode == HttpStatus.ok) return json;
      // e.g. "WEAK_PASSWORD : Password should be at least 6 characters"
      final message =
          ((json['error'] as Map?)?['message'] as String?) ?? 'UNKNOWN';
      throw FirebaseRestError(message.split(' ').first);
    };
  }
}
