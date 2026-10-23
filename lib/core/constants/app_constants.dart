class AppConstants {
  AppConstants._();

  static const String appName = 'Food Expiration Reminder';

  /// Shown in Profile → About. Must match `version:` in pubspec.yaml
  /// (checked by test/core/app_version_test.dart).
  static const String appVersion = '2.0.0';

  /// Items expiring within this many days are flagged "Use Soon".
  static const int useSoonThresholdDays = 3;

  static const List<String> accountTypes = [
    'Personal',
    'Student',
    'Family',
    'Shared house',
  ];

  static const double pagePadding = 20;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 24;

  static const List<String> categories = [
    'Dairy',
    'Meat & Seafood',
    'Produce',
    'Fruits',
    'Vegetables',
    'Bakery',
    'Beverages',
    'Canned & Dry Goods',
    'Condiments',
    'Leftovers',
    'Frozen',
    'Snacks',
  ];
}
