import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiration_reminder/core/widgets/category_field.dart';

void main() {
  final suggestions = CategoryField.suggestionsFrom(['Spices', 'dairy']);

  test('suggestions: built-ins first, household extras added once', () {
    expect(suggestions.first, 'Dairy');
    expect(suggestions, contains('Fruits'));
    expect(suggestions, contains('Spices'));
    expect(suggestions.where((s) => s.toLowerCase() == 'dairy'), hasLength(1));
  });

  test('normalize reuses known spellings and tidies new ones', () {
    expect(CategoryField.normalize('  dairy ', suggestions), 'Dairy');
    expect(CategoryField.normalize('FRUITS', suggestions), 'Fruits');
    expect(CategoryField.normalize('baby   food', suggestions), 'Baby food');
    expect(CategoryField.normalize('   ', suggestions), isNull);
  });
}
