/// Splits free-text grocery quantities into the inventory's number + unit:
/// "2 L" → (2, "L"), "500g" → (500, "g"), "1 tray" → (1, "tray").
/// Anything without a leading whole number becomes one of that thing:
/// "a dozen" → (1, "a dozen"), "1.5 kg" → (1, "1.5 kg").
({int quantity, String unit}) parseQuantity(String text) {
  final t = text.trim();
  final match = RegExp(r'^(\d+)\s*([^\d.,].*)?$').firstMatch(t);
  if (match != null) {
    final n = int.parse(match.group(1)!);
    final unit = match.group(2)?.trim() ?? '';
    if (n > 0) return (quantity: n, unit: unit.isEmpty ? 'pcs' : unit);
  }
  return (quantity: 1, unit: t.isEmpty ? 'pcs' : t);
}
