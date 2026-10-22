import 'package:flutter/material.dart';

enum StorageLocation { fridge, freezer, pantry, cabinet }

extension StorageLocationX on StorageLocation {
  String get label => switch (this) {
        StorageLocation.fridge => 'Fridge',
        StorageLocation.freezer => 'Freezer',
        StorageLocation.pantry => 'Pantry',
        StorageLocation.cabinet => 'Cabinet',
      };

  String get fullLabel => switch (this) {
        StorageLocation.fridge => 'Refrigerator',
        StorageLocation.freezer => 'Freezer',
        StorageLocation.pantry => 'Pantry',
        StorageLocation.cabinet => 'Cabinet',
      };

  IconData get icon => switch (this) {
        StorageLocation.fridge => Icons.kitchen_rounded,
        StorageLocation.freezer => Icons.ac_unit_rounded,
        StorageLocation.pantry => Icons.shelves,
        StorageLocation.cabinet => Icons.inventory_2_rounded,
      };
}
