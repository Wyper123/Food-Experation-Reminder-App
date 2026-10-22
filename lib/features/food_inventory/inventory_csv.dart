import 'package:food_expiration_reminder/core/constants/storage_locations.dart';
import 'package:food_expiration_reminder/core/utils/status_color_helper.dart';
import 'package:food_expiration_reminder/data/models/food_item_model.dart';
import 'package:intl/intl.dart';

/// The inventory as CSV (RFC 4180), soonest expiration first. Opens in
/// Excel/Google Sheets; dates are ISO so spreadsheets sort them correctly.
String inventoryToCsv(List<FoodItemModel> items) {
  final date = DateFormat('yyyy-MM-dd');
  String cell(Object? v) {
    final s = v?.toString() ?? '';
    return s.contains(RegExp(r'[",\r\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  final sorted = [...items]
    ..sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
  final rows = [
    [
      'Name',
      'Category',
      'Quantity',
      'Unit',
      'Brand',
      'Storage',
      'Purchased',
      'Expires',
      'Opened',
      'Status',
      'Days left',
    ],
    for (final e in sorted)
      [
        e.name,
        e.category,
        e.quantity,
        e.unit,
        e.brand,
        e.storage.fullLabel,
        date.format(e.purchaseDate),
        date.format(e.expirationDate),
        e.openingDate == null ? '' : date.format(e.openingDate!),
        StatusColorHelper.label(e.effectiveStatus),
        e.isActive ? e.daysRemaining : '',
      ],
  ];
  // CRLF line endings per RFC 4180; Excel expects them.
  return '${rows.map((r) => r.map(cell).join(',')).join('\r\n')}\r\n';
}
