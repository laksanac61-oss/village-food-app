import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/income.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/common.dart';
import '../../widgets/stars.dart';

/// The shop's income by day, month and year with a chart, best-selling dishes, and customer ratings.
class ShopIncome extends StatefulWidget {
  const ShopIncome({super.key, required this.shop});
  final Shop shop;

  @override
  State<ShopIncome> createState() => _ShopIncomeState();
}

class _IncomeData {
  _IncomeData(this.series, this.rating, this.reviews);
  final Map<String, List<RevenueRow>> series; // unit -> one row per period, oldest first
  final ShopRating rating;
  final List<Map<String, dynamic>> reviews;
}

class _ShopIncomeState extends State<ShopIncome> {
  String _unit = 'day';
  int? _selected; // index of the tapped bar; null = the whole range

  Future<_IncomeData> _load() async {
    final today = DateTime.now();
    final series = <String, List<RevenueRow>>{};
    for (final unit in const ['day', 'month', 'year']) {
      final (from, to) = incomeRange(unit, today);
      series[unit] = fillPeriods(await Api.shopRevenue(widget.shop.id, unit, from, to), unit, from, to);
    }
    final ratings = await Api.shopRatings();
    final reviews = await Api.shopReviews(widget.shop.id);
    return _IncomeData(series, ratings[widget.shop.id] ?? ShopRating.none, reviews);
  }

  @override
  Widget build(BuildContext context) => Loader<_IncomeData>(
    load: _load,
    reloadOn: Api.orderChanges(),
    builder: (context, data, reload) {
      final rows = data.series[_unit]!;
      final sel = _selected != null && _selected! < rows.length ? _selected : null;
      RevenueRow current(String unit) => data.series[unit]!.last;
      final (from, to) = sel == null ? incomeRange(_unit, DateTime.now()) : _periodRange(rows[sel].bucket);
      final shown = sel == null ? rows : [rows[sel]];
      final total = shown.fold<double>(0, (s, r) => s + r.food);
      final orders = shown.fold<int>(0, (s, r) => s + r.orders);
      final cash = shown.fold<double>(0, (s, r) => s + r.cash);
      final qr = shown.fold<double>(0, (s, r) => s + r.promptpay);
      return ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                _Summary('วันนี้', current('day')),
                _Summary('เดือนนี้', current('month')),
                _Summary('ปีนี้', current('year')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'day', label: Text('รายวัน')),
                ButtonSegment(value: 'month', label: Text('รายเดือน')),
                ButtonSegment(value: 'year', label: Text('รายปี')),
              ],
              selected: {_unit},
              onSelectionChanged: (s) => setState(() {
                _unit = s.first;
                _selected = null;
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
            child: BarChart(
              values: [for (final r in rows) r.food],
              labels: [for (final r in rows) periodLabel(_unit, r.bucket)],
              topLabels: [for (final r in rows) shortBaht(r.food)],
              selected: sel,
              onSelect: (i) => setState(() => _selected = _selected == i ? null : i),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'แตะแท่งกราฟเพื่อดูรายละเอียด แตะซ้ำเพื่อดูทั้งช่วง',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sel == null ? _rangeTitle(rows) : periodTitle(_unit, rows[sel].bucket),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    baht(total),
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$orders ออเดอร์'
                    '${orders > 0 ? ' · เฉลี่ย ${baht((total / orders).roundToDouble())} ต่อออเดอร์' : ''}',
                  ),
                  if (total > 0) Text('สแกน QR ${baht(qr)} · เงินสด ${baht(cash)}'),
                ],
              ),
            ),
          ),
          _TopItems(shopId: widget.shop.id, from: from, to: to),
          _Ratings(rating: data.rating, reviews: data.reviews),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'นับเฉพาะออเดอร์ที่สำเร็จแล้ว เป็นค่าอาหารอย่างเดียว ไม่รวมค่าส่ง (ค่าส่งเป็นของไรเดอร์) '
              'ออเดอร์จองล่วงหน้านับตามวันที่จองรับ',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
      );
    },
  );

  (DateTime, DateTime) _periodRange(DateTime start) => switch (_unit) {
    'day' => (start, start),
    'month' => (start, DateTime(start.year, start.month + 1, 0)),
    _ => (start, DateTime(start.year, 12, 31)),
  };

  String _rangeTitle(List<RevenueRow> rows) => switch (_unit) {
    'day' => '14 วันล่าสุด',
    'month' => '12 เดือนล่าสุด',
    _ => '${periodTitle('year', rows.first.bucket)} ถึง ${rows.last.bucket.year + 543}',
  };
}

class _Summary extends StatelessWidget {
  const _Summary(this.label, this.row);
  final String label;
  final RevenueRow row;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          children: [
            Text(label),
            FittedBox(
              child: Text(baht(row.food), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Text('${row.orders} ออเดอร์', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

/// Best-selling dishes in the chosen range.
class _TopItems extends StatelessWidget {
  const _TopItems({required this.shopId, required this.from, required this.to});
  final String shopId;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    // a new future when the range changes
    key: ValueKey('$from$to'),
    future: Api.shopTopItems(shopId, from, to),
    builder: (context, snap) {
      final items = snap.data ?? const [];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('เมนูขายดีในช่วงนี้', style: Theme.of(context).textTheme.titleMedium),
          ),
          if (snap.connectionState != ConnectionState.done)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('ยังไม่มีออเดอร์ที่สำเร็จในช่วงนี้', style: TextStyle(color: Colors.grey)),
            )
          else
            for (final (i, m) in items.take(5).indexed)
              ListTile(
                dense: true,
                leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
                title: Text(m['name'] ?? '-'),
                trailing: Text('${m['qty']} จาน · ${baht((m['amount'] as num).toDouble())}'),
              ),
        ],
      );
    },
  );
}

class _Ratings extends StatelessWidget {
  const _Ratings({required this.rating, required this.reviews});
  final ShopRating rating;
  final List<Map<String, dynamic>> reviews;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('คะแนนจากลูกค้า', style: Theme.of(context).textTheme.titleMedium),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: rating.stars == null
            ? const Text('ยังไม่มีรีวิว ลูกค้าให้ดาวได้หลังได้รับอาหาร', style: TextStyle(color: Colors.grey))
            : Row(
                children: [
                  Text(
                    rating.stars!.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Stars(rating.stars!, size: 20), Text('จาก ${rating.reviews} รีวิว')],
                  ),
                ],
              ),
      ),
      for (final r in reviews.where((r) => (r['comment'] ?? '').toString().isNotEmpty).take(5))
        ListTile(
          dense: true,
          title: Text(r['comment']),
          subtitle: Align(
            alignment: Alignment.centerLeft,
            child: Stars((r['stars'] as num).toDouble(), size: 14),
          ),
        ),
    ],
  );
}
