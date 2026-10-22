import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';

/// Horizontally scrolling single-select chip row.
class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.icons,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final Map<String, IconData>? icons;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final option = options[i];
          final isSelected = option == selected;
          final icon = icons?[option];
          final fg = isSelected ? cs.onPrimary : cs.onSurface;
          return ChoiceChip(
            label: Text(option),
            avatar: icon == null
                ? null
                : Icon(
                    icon,
                    size: 18,
                    color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onSelected(option),
            selectedColor: cs.primary,
            backgroundColor: cs.surfaceContainerLowest,
            side: BorderSide(
              color: isSelected ? cs.primary : cs.outlineVariant,
            ),
            shape: const StadiumBorder(),
            labelStyle: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          );
        },
      ),
    );
  }
}
