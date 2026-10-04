// Turning income rows from the database into a full series for the chart: every day, month or year in the
// range gets a bar, including periods with no sales.

import 'models.dart';

const thaiMonths = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

/// The chart range for each unit, ending today: 14 days, 12 months or 5 years.
(DateTime, DateTime) incomeRange(String unit, DateTime today) {
  final end = DateTime(today.year, today.month, today.day);
  return switch (unit) {
    'day' => (end.subtract(const Duration(days: 13)), end),
    'month' => (DateTime(end.year, end.month - 11, 1), end),
    _ => (DateTime(end.year - 4, 1, 1), end),
  };
}

DateTime _start(String unit, DateTime d) => switch (unit) {
  'day' => DateTime(d.year, d.month, d.day),
  'month' => DateTime(d.year, d.month, 1),
  _ => DateTime(d.year, 1, 1),
};

DateTime _next(String unit, DateTime d) => switch (unit) {
  'day' => DateTime(d.year, d.month, d.day + 1),
  'month' => DateTime(d.year, d.month + 1, 1),
  _ => DateTime(d.year + 1, 1, 1),
};

/// One row per period from [from] to [to], zero where nothing was sold.
List<RevenueRow> fillPeriods(List<RevenueRow> rows, String unit, DateTime from, DateTime to) {
  final byStart = {for (final r in rows) _start(unit, r.bucket): r};
  final out = <RevenueRow>[];
  for (var d = _start(unit, from); !d.isAfter(to); d = _next(unit, d)) {
    out.add(byStart[d] ?? RevenueRow(d, 0, 0));
  }
  return out;
}

/// Short label under a bar: day "4/10", month "ต.ค.", year in the Thai calendar "2569".
String periodLabel(String unit, DateTime d) => switch (unit) {
  'day' => '${d.day}/${d.month}',
  'month' => thaiMonths[d.month - 1],
  _ => '${d.year + 543}',
};

/// Longer label for lists: "4 ต.ค. 2569", "ต.ค. 2569", "2569".
String periodTitle(String unit, DateTime d) => switch (unit) {
  'day' => '${d.day} ${thaiMonths[d.month - 1]} ${d.year + 543}',
  'month' => '${thaiMonths[d.month - 1]} ${d.year + 543}',
  _ => 'ปี ${d.year + 543}',
};

/// 950 -> "950", 1250 -> "1.3k", 25000 -> "25k" for bar tops.
String shortBaht(double v) {
  if (v < 1000) return v.toStringAsFixed(0);
  final k = v / 1000;
  return '${k >= 10 ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
}
