import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/storage_locations.dart';
import 'package:food_expiration_reminder/core/widgets/filter_chip_bar.dart';

/// Category chips: All, Refrigerator, Freezer, Pantry, Cabinet.
class StorageFilterTabs extends StatelessWidget {
  const StorageFilterTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// null means "All".
  final StorageLocation? selected;
  final ValueChanged<StorageLocation?> onChanged;

  static const String _all = 'All places';

  @override
  Widget build(BuildContext context) {
    return FilterChipBar(
      options: [_all, ...StorageLocation.values.map((e) => e.fullLabel)],
      selected: selected?.fullLabel ?? _all,
      icons: {
        _all: Icons.apps_rounded,
        for (final l in StorageLocation.values) l.fullLabel: l.icon,
      },
      onSelected: (label) {
        if (label == _all) {
          onChanged(null);
        } else {
          onChanged(
            StorageLocation.values.firstWhere((e) => e.fullLabel == label),
          );
        }
      },
    );
  }
}
