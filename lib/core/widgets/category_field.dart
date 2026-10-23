import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_constants.dart';
import 'package:food_expiration_reminder/core/widgets/custom_text_field.dart';

/// Free-text category with suggestions: pick a known one or type your own
/// ("Fruits", "Spices", …). [onChanged] receives the tidied value, or null
/// when empty.
class CategoryField extends StatelessWidget {
  const CategoryField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.extraSuggestions = const [],
    this.isRequired = true,
    this.label = 'Category',
    this.showIcon = true,
  });

  final String? initialValue;
  final ValueChanged<String?> onChanged;

  /// Categories already in use (e.g. from the inventory), suggested too.
  final Iterable<String> extraSuggestions;
  final bool isRequired;
  final String label;
  final bool showIcon;

  /// Built-in categories first, then the household's own, without repeats.
  static List<String> suggestionsFrom(Iterable<String> extra) {
    final seen = <String>{};
    return [
      for (final c in [...AppConstants.categories, ...extra])
        if (c.trim().isNotEmpty && seen.add(c.trim().toLowerCase())) c.trim(),
    ];
  }

  /// Trims and collapses spaces, reuses a suggestion's spelling when it
  /// matches ("dairy" → "Dairy"), and otherwise capitalises the first letter.
  static String? normalize(String text, Iterable<String> suggestions) {
    final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return null;
    for (final s in suggestions) {
      if (s.toLowerCase() == t.toLowerCase()) return s;
    }
    return t[0].toUpperCase() + t.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = suggestionsFrom(extraSuggestions);
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: initialValue ?? ''),
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return suggestions;
        return suggestions.where((s) => s.toLowerCase().contains(q));
      },
      onSelected: (s) => onChanged(s),
      fieldViewBuilder: (context, controller, focusNode, onSubmit) =>
          TextFormField(
        controller: controller,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        onChanged: (v) => onChanged(normalize(v, suggestions)),
        onFieldSubmitted: (_) => onSubmit(),
        validator: (v) => isRequired && normalize(v ?? '', suggestions) == null
            ? 'Enter a category'
            : null,
        decoration: CustomTextField.decoration(
          context,
          label: label,
          hint: 'e.g. Fruits',
          prefixIcon: showIcon ? Icons.category_outlined : null,
        ),
      ),
    );
  }
}
