import 'package:food_expiration_reminder/core/security/password_hasher.dart';

/// Cheap enough for tests and runs inline (no isolate), so it also works on
/// a widget test's fake clock.
const fastHasher = PasswordHasher(iterations: 500, useIsolate: false);
