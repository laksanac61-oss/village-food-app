import 'package:flutter_test/flutter_test.dart';
import 'package:village_food/core/income.dart';
import 'package:village_food/core/models.dart';

void main() {
  final today = DateTime(2026, 10, 4, 15, 30);

  test('ranges end today: 14 days, 12 months, 5 years', () {
    expect(incomeRange('day', today), (DateTime(2026, 9, 21), DateTime(2026, 10, 4)));
    expect(incomeRange('month', today).$1, DateTime(2025, 11, 1));
    expect(incomeRange('year', today).$1, DateTime(2022, 1, 1));
  });

  test('periods without sales get a zero bar', () {
    final (from, to) = incomeRange('day', today);
    final rows = fillPeriods(
      [RevenueRow(DateTime(2026, 10, 3), 2, 150), RevenueRow(DateTime(2026, 10, 4), 1, 50)],
      'day',
      from,
      to,
    );
    expect(rows, hasLength(14));
    expect(rows.first.food, 0);
    expect(rows[12].food, 150);
    expect(rows.last.orders, 1);
  });

  test('months across a year boundary', () {
    final (from, to) = incomeRange('month', today);
    final rows = fillPeriods([RevenueRow(DateTime(2026, 1, 1), 5, 900)], 'month', from, to);
    expect(rows, hasLength(12));
    expect(rows.map((r) => r.bucket.month).take(3), [11, 12, 1]);
    expect(rows[2].food, 900);
  });

  test('Thai labels', () {
    expect(periodLabel('day', DateTime(2026, 10, 4)), '4/10');
    expect(periodLabel('month', DateTime(2026, 10, 1)), 'ต.ค.');
    expect(periodLabel('year', DateTime(2026, 1, 1)), '2569');
    expect(periodTitle('day', DateTime(2026, 10, 4)), '4 ต.ค. 2569');
    expect(shortBaht(950), '950');
    expect(shortBaht(1250), '1.3k');
    expect(shortBaht(25000), '25k');
  });
}
