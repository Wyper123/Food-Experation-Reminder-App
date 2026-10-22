import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 with a random 16-byte salt per password.
///
/// Stored format: `pbkdf2_sha256$<iterations>$<salt b64>$<hash b64>`, so the
/// iteration count can be raised later without breaking existing accounts.
class PasswordHasher {
  const PasswordHasher({
    this.iterations = defaultIterations,
    this.useIsolate = true,
  });

  /// Tuned to stay well under a second on mid-range phones in release mode.
  static const int defaultIterations = 60000;
  static const String _scheme = 'pbkdf2_sha256';

  final int iterations;

  /// Runs the key derivation off the UI thread. Disabled in widget tests,
  /// where isolates cannot complete on the fake clock.
  final bool useIsolate;

  Future<String> hash(String password) {
    final rng = Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
    return _run(() {
      final key = _pbkdf2(utf8.encode(password), salt, iterations);
      return [
        _scheme,
        '$iterations',
        base64.encode(salt),
        base64.encode(key),
      ].join(r'$');
    });
  }

  /// False for a wrong password or a malformed/unusable stored hash.
  Future<bool> verify(String password, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _scheme) return Future.value(false);
    final rounds = int.tryParse(parts[1]);
    if (rounds == null || rounds < 1) return Future.value(false);
    final List<int> salt;
    final List<int> expected;
    try {
      salt = base64.decode(parts[2]);
      expected = base64.decode(parts[3]);
    } on FormatException {
      return Future.value(false);
    }
    return _run(() {
      final actual = _pbkdf2(utf8.encode(password), salt, rounds);
      return _constantTimeEquals(actual, expected);
    });
  }

  Future<T> _run<T>(T Function() work) =>
      useIsolate ? Isolate.run(work) : Future.value(work());

  /// Single-block PBKDF2: SHA-256 output (32 bytes) is the derived key length.
  static List<int> _pbkdf2(List<int> password, List<int> salt, int rounds) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final out = List<int>.of(u);
    for (var i = 1; i < rounds; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
