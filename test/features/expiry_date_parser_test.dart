import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiration_reminder/features/food_inventory/scanning/expiry_date_parser.dart';

void main() {
  final today = DateTime(2026, 10, 22);

  DateTime? best(String text) {
    final found = findExpiryDates(text, today: today);
    return found.isEmpty ? null : found.first.date;
  }

  List<DateTime> all(String text) =>
      findExpiryDates(text, today: today).map((c) => c.date).toList();

  group('formats', () {
    test('ISO year-first', () {
      expect(best('EXP 2027-03-15'), DateTime(2027, 3, 15));
      expect(best('2027/3/5'), DateTime(2027, 3, 5));
    });

    test('day and written month', () {
      expect(best('BEST BEFORE 05 DEC 2026'), DateTime(2026, 12, 5));
      expect(best('5-Dec-26'), DateTime(2026, 12, 5));
      expect(best('EXP 05DEC2026'), DateTime(2026, 12, 5));
      expect(best('use by 1 september 2027'), DateTime(2027, 9, 1));
    });

    test('written month then day', () {
      expect(best('BB DEC 05 2026'), DateTime(2026, 12, 5));
      expect(best('Best by December 5, 2026'), DateTime(2026, 12, 5));
    });

    test('month and year only means the end of that month', () {
      expect(best('BEST BEFORE: DEC 2026'), DateTime(2026, 12, 31));
      expect(best('EXP FEB-28'), DateTime(2028, 2, 29));
      expect(best('EXP 02/2027'), DateTime(2027, 2, 28));
    });

    test('unambiguous numeric day/month order', () {
      expect(best('EXP 25/12/2026'), DateTime(2026, 12, 25));
      expect(best('EXP 12/25/2026'), DateTime(2026, 12, 25));
      expect(best('EXP 25.12.26'), DateTime(2026, 12, 25));
    });

    test('ambiguous numeric dates offer both readings', () {
      final dates = all('EXP 05/11/2026');
      expect(dates, containsAll([DateTime(2026, 11, 5), DateTime(2026, 5, 11)]));
      // Only the future reading gets the "not in the past" bonus.
      expect(dates.first, DateTime(2026, 11, 5));
    });

    test('ambiguous future dates offer both for the user to choose', () {
      expect(
        all('EXP 12/05/2027'),
        containsAll([DateTime(2027, 5, 12), DateTime(2027, 12, 5)]),
      );
    });

    test('OCR reading 0 as O inside numbers', () {
      expect(best('EXP 25/O5/2O27'), DateTime(2027, 5, 25));
    });
  });

  group('choosing the expiry date', () {
    test('prefers the date after an expiry keyword over MFG', () {
      expect(
        best('MFG 01/02/2026 EXP 01/02/2028'),
        DateTime(2028, 2, 1),
      );
      expect(
        best('EXP 30/11/2026\nMFG 30/05/2026'),
        DateTime(2026, 11, 30),
      );
    });

    test('keyword on the line above counts', () {
      expect(best('BEST BEFORE\n14 JAN 2027'), DateTime(2027, 1, 14));
    });

    test('ranks a manufacturing date last', () {
      final found = findExpiryDates(
        'PKD 10 OCT 2026  USE BY 20 OCT 2026',
        today: today,
      );
      expect(found.first.date, DateTime(2026, 10, 20));
      expect(found.last.date, DateTime(2026, 10, 10));
    });

    test('without keywords the later date wins a tie', () {
      expect(best('10 JAN 2027   10 MAR 2027'), DateTime(2027, 3, 10));
    });
  });

  group('rejects', () {
    test('impossible dates and plain numbers', () {
      expect(all('31/02/2026'), isEmpty);
      expect(all('LOT 4471 NET WT 500G'), isEmpty);
      expect(all('PRICE 125.50'), isEmpty);
    });

    test('dates far in the past or future', () {
      expect(all('EXP 01/01/2015'), isEmpty);
      expect(all('EXP 01/01/2099'), isEmpty);
    });
  });
}
