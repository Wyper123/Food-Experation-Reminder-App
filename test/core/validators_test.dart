import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiration_reminder/core/utils/validators.dart';

void main() {
  final today = DateTime(2026, 10, 22);
  final yesterday = DateTime(2026, 10, 21);
  final tomorrow = DateTime(2026, 10, 23);

  test('purchase date cannot be in the future', () {
    expect(Validators.purchaseDate(today, today), isNull);
    expect(Validators.purchaseDate(tomorrow, today), isNotNull);
  });

  test('expiration is required and not before purchase', () {
    expect(Validators.expirationDate(null, today), 'Set an expiration date');
    expect(Validators.expirationDate(yesterday, today), isNotNull);
    expect(Validators.expirationDate(today, today), isNull, reason: 'same day');
    // Already-expired food can still be logged.
    expect(Validators.expirationDate(yesterday, yesterday), isNull);
  });

  test('opening date is optional, after purchase, not in the future', () {
    expect(Validators.openingDate(null, yesterday, today), isNull);
    expect(Validators.openingDate(today, yesterday, today), isNull);
    expect(
      Validators.openingDate(DateTime(2026, 10, 20), yesterday, today),
      isNotNull,
    );
    expect(Validators.openingDate(tomorrow, yesterday, today), isNotNull);
  });

  test('email', () {
    expect(Validators.email(' a@b.co '), isNull);
    for (final bad in ['', 'a@b', 'a b@c.d', '@b.co']) {
      expect(Validators.email(bad), isNotNull, reason: bad);
    }
  });
}
