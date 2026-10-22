/// Form validators shared by auth and profile screens.
class Validators {
  Validators._();

  static const int minPasswordLength = 8;

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? v) =>
      (v == null || !_email.hasMatch(v.trim())) ? 'Enter a valid email' : null;

  static String? required(String? v, String message) =>
      (v == null || v.trim().isEmpty) ? message : null;

  /// For new passwords. Sign-in only checks that a password was entered.
  static String? newPassword(String? v) =>
      (v == null || v.length < minPasswordLength)
          ? 'At least $minPasswordLength characters'
          : null;

  // Food dates. All arguments are date-only values (midnight).

  static String? purchaseDate(DateTime purchase, DateTime today) =>
      purchase.isAfter(today) ? 'Purchase date cannot be in the future' : null;

  static String? expirationDate(DateTime? expiration, DateTime purchase) {
    if (expiration == null) return 'Set an expiration date';
    if (expiration.isBefore(purchase)) {
      return 'Cannot be before the purchase date';
    }
    return null;
  }

  static String? openingDate(
    DateTime? opening,
    DateTime purchase,
    DateTime today,
  ) {
    if (opening == null) return null;
    if (opening.isBefore(purchase)) return 'Cannot be before the purchase date';
    if (opening.isAfter(today)) return 'Opening date cannot be in the future';
    return null;
  }
}
