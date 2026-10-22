import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiration_reminder/core/security/password_hasher.dart';

void main() {
  const hasher = PasswordHasher(iterations: 1000);

  test('verifies the right password and rejects a wrong one', () async {
    final stored = await hasher.hash('correct horse');
    expect(stored, startsWith(r'pbkdf2_sha256$1000$'));
    expect(await hasher.verify('correct horse', stored), isTrue);
    expect(await hasher.verify('correct horsE', stored), isFalse);
  });

  test('salts each hash', () async {
    expect(await hasher.hash('same'), isNot(await hasher.hash('same')));
  });

  test('uses the iteration count stored in the hash', () async {
    final old = await const PasswordHasher(iterations: 10).hash('pw');
    expect(await hasher.verify('pw', old), isTrue);
  });

  test('rejects malformed or placeholder hashes', () async {
    for (final bad in ['', '!', r'md5$1$a$b', r'pbkdf2_sha256$x$a$b',
        r'pbkdf2_sha256$10$%%%$b']) {
      expect(await hasher.verify('pw', bad), isFalse, reason: bad);
    }
  });

  test('matches the RFC 7914 PBKDF2-HMAC-SHA256 test vector', () async {
    // P="passwd", S="salt", c=1 → 55ac046e56e3089f…
    const saltB64 = 'c2FsdA==';
    const keyB64 = 'VawEblbjCJ/sFpHCJUS2BflBhSFt3gRl5oudV8INrLw=';
    expect(
      await hasher.verify('passwd', 'pbkdf2_sha256\$1\$$saltB64\$$keyB64'),
      isTrue,
    );
  });
}
