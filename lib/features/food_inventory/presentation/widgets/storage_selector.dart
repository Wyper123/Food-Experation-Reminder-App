import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/constants/storage_locations.dart';

/// Fridge / Freezer / Pantry / Cabinet picker. Two per row on phones so
/// labels never wrap mid-word (a 4-segment row did on 360dp screens); four
/// in a row when there is room.
class StorageSelector extends StatelessWidget {
  const StorageSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// Null highlights nothing (e.g. items stored in different places).
  final StorageLocation? selected;
  final ValueChanged<StorageLocation> onChanged;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final perRow = c.maxWidth >= 520 ? 4 : 2;
        final width = (c.maxWidth - _gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final s in StorageLocation.values)
              SizedBox(
                width: width,
                child: _Option(
                  location: s,
                  selected: s == selected,
                  onTap: () => onChanged(s),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.location,
    required this.selected,
    required this.onTap,
  });

  final StorageLocation location;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? cs.primary : cs.onSurface;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? cs.primary.withValues(alpha: 0.12)
            : cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(location.icon, size: 20, color: fg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      location.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle.copyWith(color: fg),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_rounded, size: 18, color: cs.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
