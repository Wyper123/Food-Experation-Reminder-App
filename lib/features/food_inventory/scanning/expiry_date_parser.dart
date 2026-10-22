/// A date found in scanned package text.
class DateCandidate {
  const DateCandidate({
    required this.date,
    required this.source,
    required this.score,
  });

  final DateTime date;

  /// The text it was read from, e.g. "EXP 12/05/26" → "12/05/26".
  final String source;

  /// Higher is more likely to be the expiry date.
  final int score;

  @override
  String toString() => 'DateCandidate($date, "$source", $score)';
}

const _months = {
  'JAN': 1,
  'JANUARY': 1,
  'FEB': 2,
  'FEBRUARY': 2,
  'MAR': 3,
  'MARCH': 3,
  'APR': 4,
  'APRIL': 4,
  'MAY': 5,
  'JUN': 6,
  'JUNE': 6,
  'JUL': 7,
  'JULY': 7,
  'AUG': 8,
  'AUGUST': 8,
  'SEP': 9,
  'SEPT': 9,
  'SEPTEMBER': 9,
  'OCT': 10,
  'OCTOBER': 10,
  'NOV': 11,
  'NOVEMBER': 11,
  'DEC': 12,
  'DECEMBER': 12,
};

// Longest names first so "SEPTEMBER" wins over "SEP".
final _monthAlt = (_months.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length)))
    .join('|');

final _expiryWords = RegExp(
  r'\b(EXP(IRY|IRES|IRATION)?|E\.?X\.?P|BEST\s*(BEFORE|BY)|BB[DE]?|'
  r'USE\s*(BY|BEFORE)|CONSUME\s*(BY|BEFORE)|SELL\s*BY|VALID\s*UNTIL)\b',
);
final _madeWords = RegExp(
  r'\b(MFG|MFD|MANUFACTURED|MANUFACTURING|MANUF|PROD(UCED|UCTION)?|'
  r'PKD|PACKED|PACKAGED|DOM|MADE\s*ON|LOT)\b',
);

/// Finds dates in OCR [text] and ranks the likely expiry date first.
///
/// Handles numeric (12/05/26, 2026-12-05, 05.12.2026), written months
/// (05 DEC 2026, DEC 05 2026, DEC 2026) and month/year (12/2026) forms.
/// Ambiguous day/month orders yield both readings. Month-only dates use
/// the last day of that month. Dates next to EXP/BEST BEFORE/USE BY rank
/// up; ones next to MFG/PROD/PKD rank down.
List<DateCandidate> findExpiryDates(String text, {required DateTime today}) {
  final lines = text.toUpperCase().split(RegExp(r'\r?\n'));
  final found = <DateCandidate>[];
  for (var i = 0; i < lines.length; i++) {
    final line = _fixOcrDigits(lines[i]);
    final previous = i > 0 ? _fixOcrDigits(lines[i - 1]) : '';
    for (final m in _matchDates(line)) {
      final context = '$previous\n${line.substring(0, m.start)}';
      for (final reading in m.readings) {
        final score = _score(reading, m, context, today);
        if (score == null) continue;
        found.add(
          DateCandidate(date: reading.date, source: m.text, score: score),
        );
      }
    }
  }

  // One entry per date, keeping its best score.
  final best = <DateTime, DateCandidate>{};
  for (final c in found) {
    final prev = best[c.date];
    if (prev == null || c.score > prev.score) best[c.date] = c;
  }
  return best.values.toList()
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      // Expiry usually comes after any other printed date.
      return byScore != 0 ? byScore : b.date.compareTo(a.date);
    });
}

/// OCR often reads 0 as O inside numbers ("12/O5/2026").
String _fixOcrDigits(String s) => s.replaceAllMapped(
      RegExp(r'(?<=[\d/.\-])O|O(?=[\d/.\-])'),
      (_) => '0',
    );

class _Reading {
  const _Reading(this.date, {this.ambiguous = false, this.monthOnly = false});
  final DateTime date;
  final bool ambiguous;
  final bool monthOnly;
}

class _Match {
  _Match(this.start, this.end, this.text, this.readings, {this.named = false});
  final int start;
  final int end;
  final String text;
  final List<_Reading> readings;

  /// Written month name: unambiguous.
  final bool named;
}

int _year(String y) {
  final n = int.parse(y);
  return y.length == 2 ? 2000 + n : n;
}

/// Null if the parts do not form a real calendar date.
DateTime? _date(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final date = DateTime(y, m, d);
  return date.month == m && date.day == d ? date : null;
}

DateTime _endOfMonth(int y, int m) => DateTime(y, m + 1, 0);

List<_Match> _matchDates(String line) {
  const sep = r'\s*[/\-.]\s*';
  final patterns = <(RegExp, _Match? Function(RegExpMatch))>[
    // 2026-12-05
    (
      RegExp(r'\b(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})\b'),
      (m) {
        final d = _date(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
        return d == null ? null : _Match(m.start, m.end, m[0]!, [_Reading(d)]);
      },
    ),
    // 05 DEC 2026, 5-Dec-26, 05DEC2026
    (
      RegExp('\\b(\\d{1,2})\\s*[/\\-.]?\\s*($_monthAlt)\\.?\\s*[/\\-.,]?\\s*'
          '(\\d{4}|\\d{2})\\b'),
      (m) {
        final d = _date(_year(m[3]!), _months[m[2]]!, int.parse(m[1]!));
        return d == null
            ? null
            : _Match(m.start, m.end, m[0]!, [_Reading(d)], named: true);
      },
    ),
    // DEC 05 2026, December 5, 2026
    (
      RegExp('\\b($_monthAlt)\\.?\\s*[/\\-.]?\\s*(\\d{1,2})\\s*,?\\s*'
          '[/\\-.]?\\s*(\\d{4})\\b'),
      (m) {
        final d = _date(_year(m[3]!), _months[m[1]]!, int.parse(m[2]!));
        return d == null
            ? null
            : _Match(m.start, m.end, m[0]!, [_Reading(d)], named: true);
      },
    ),
    // DEC 2026, DEC-26
    (
      RegExp('\\b($_monthAlt)\\.?\\s*[/\\-.]?\\s*(\\d{4}|\\d{2})\\b'),
      (m) => _Match(
            m.start,
            m.end,
            m[0]!,
            [
              _Reading(_endOfMonth(_year(m[2]!), _months[m[1]]!),
                  monthOnly: true)
            ],
            named: true,
          ),
    ),
    // 12/05/26, 05.12.2026, 12 05 2026
    (
      RegExp(
          '\\b(\\d{1,2})(?:$sep|\\s+)(\\d{1,2})(?:$sep|\\s+)(\\d{4}|\\d{2})\\b'),
      (m) {
        final a = int.parse(m[1]!), b = int.parse(m[2]!), y = _year(m[3]!);
        // Day-first is the international default; month-first if it must be.
        final dmy = _date(y, b, a), mdy = _date(y, a, b);
        final both = dmy != null && mdy != null && dmy != mdy;
        final readings = [
          if (dmy != null) _Reading(dmy, ambiguous: both),
          if (mdy != null && mdy != dmy) _Reading(mdy, ambiguous: both),
        ];
        return readings.isEmpty
            ? null
            : _Match(m.start, m.end, m[0]!, readings);
      },
    ),
    // 12/2026
    (
      RegExp(r'\b(\d{1,2})[/\-.](\d{4})\b'),
      (m) {
        final month = int.parse(m[1]!);
        if (month < 1 || month > 12) return null;
        return _Match(m.start, m.end, m[0]!, [
          _Reading(_endOfMonth(int.parse(m[2]!), month), monthOnly: true),
        ]);
      },
    ),
  ];

  final matches = <_Match>[];
  // Earlier (more specific) patterns own their characters, even when the
  // text is not a real date: "31/02/2026" must not become "02/2026".
  final taken = <(int, int)>[];
  for (final (re, build) in patterns) {
    for (final m in re.allMatches(line)) {
      if (taken.any((t) => m.start < t.$2 && t.$1 < m.end)) continue;
      taken.add((m.start, m.end));
      final match = build(m);
      if (match != null) matches.add(match);
    }
  }
  return matches;
}

/// Null when the reading is implausible for a food expiry date.
int? _score(_Reading r, _Match m, String context, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  if (r.date.isBefore(DateTime(day.year - 2, day.month, day.day)) ||
      r.date.isAfter(DateTime(day.year + 15, day.month, day.day))) {
    return null;
  }
  var score = 0;
  final expiryAt = _lastIndex(_expiryWords, context);
  final madeAt = _lastIndex(_madeWords, context);
  if (expiryAt > madeAt) score += 3;
  if (madeAt > expiryAt) score -= 3;
  if (m.named || RegExp(r'\d{4}').hasMatch(m.text)) score += 1;
  if (!r.date.isBefore(day)) score += 1;
  if (r.ambiguous) score -= 1;
  if (r.monthOnly) score -= 1;
  return score;
}

int _lastIndex(RegExp re, String s) {
  var last = -1;
  for (final m in re.allMatches(s)) {
    last = m.start;
  }
  return last;
}
