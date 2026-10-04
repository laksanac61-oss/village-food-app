import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../core/schedule.dart';
import '../../widgets/common.dart';

/// Tap target above the shop's order list when there are bookings: the next round's start time.
class PreorderSummary extends StatelessWidget {
  const PreorderSummary({super.key, required this.shop, required this.orders});
  final Shop shop;
  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    final rounds = planRounds(orders, shop: shop.location, prepMinutes: shop.prepMinutes);
    final next = rounds.firstOrNull;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.event_note),
        title: Text(
          next == null
              ? 'จองล่วงหน้า: ยังไม่มีออเดอร์จอง'
              : 'จองล่วงหน้า ${orders.where((o) => o.isPreorder && !o.isClosed).length} ออเดอร์ · ${rounds.length} รอบ',
        ),
        subtitle: Text(
          next == null
              ? (shop.acceptsPreorder
                    ? 'ลูกค้าจองเวลารับอาหารได้ แตะเพื่อตั้งค่า'
                    : 'ปิดรับจองอยู่ แตะเพื่อเปิด')
              : 'รอบถัดไป ${slotLabel(next.time)} น. · เริ่มทำ ${hhmm(next.startCooking)} น.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => ShopPreorderScreen(shopId: shop.id))),
      ),
    );
  }
}

/// Booked orders grouped into delivery rounds, with when to start cooking and what to prepare.
class ShopPreorderScreen extends StatelessWidget {
  const ShopPreorderScreen({super.key, required this.shopId});
  final String shopId;

  Future<(Shop, List<Order>)> _load() async => (await Api.shop(shopId), await Api.shopOrders(shopId));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ออเดอร์จองล่วงหน้า')),
    body: Loader<(Shop, List<Order>)>(
      load: _load,
      reloadOn: Api.orderChanges(),
      builder: (context, data, reload) {
        final (shop, orders) = data;
        final rounds = planRounds(orders, shop: shop.location, prepMinutes: shop.prepMinutes);
        final byDay = <String, List<Order>>{};
        for (final r in rounds) {
          byDay.putIfAbsent(slotLabel(r.time).split(' ').first, () => []).addAll(r.stops);
        }
        Future<void> save(Map<String, dynamic> fields) async {
          if (await guard(context, () => Api.updateShop(shop.id, fields))) reload();
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            SwitchListTile(
              title: const Text('รับจองล่วงหน้า'),
              subtitle: const Text(
                'ลูกค้าจองเวลารับอาหารได้ แม้ตอนร้านปิด (จองก่อนอย่างน้อย 30 นาที ไม่เกิน 3 วัน)',
              ),
              value: shop.acceptsPreorder,
              onChanged: (v) => save({'accepts_preorder': v}),
            ),
            ListTile(
              title: const Text('ร้านใช้เวลาทำอาหารต่อรอบ'),
              subtitle: const Text('ใช้คำนวณเวลาที่ควรเริ่มทำ'),
              trailing: DropdownButton<int>(
                value: shop.prepMinutes,
                items: [
                  for (final m in {
                    ...const [10, 15, 20, 30, 45, 60],
                    shop.prepMinutes,
                  }.toList()..sort())
                    DropdownMenuItem(value: m, child: Text('$m นาที')),
                ],
                onChanged: (m) => m == null ? null : save({'prep_minutes': m}),
              ),
            ),
            if (shop.location == null)
              const ListTile(
                leading: Icon(Icons.info_outline, color: Colors.orange),
                title: Text('ยังไม่ได้ปักหมุดร้าน'),
                subtitle: Text('ปักหมุดร้านที่แท็บ "ตั้งค่าร้าน" เพื่อคำนวณเวลาเดินทางให้แม่นขึ้น'),
              ),
            const Divider(),
            if (rounds.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('ยังไม่มีออเดอร์จอง')),
              ),
            if (rounds.isNotEmpty) ...[
              const _H('สรุปวัตถุดิบที่ต้องเตรียม'),
              for (final e in byDay.entries)
                ListTile(
                  dense: true,
                  title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_dishText(dishTotals(e.value))),
                ),
              const _H('รอบส่ง เรียงตามเวลา'),
              for (final r in rounds) _RoundCard(round: r),
            ],
          ],
        );
      },
    ),
  );
}

String _dishText(Map<String, int> dishes) => dishes.entries.map((e) => '${e.key} ${e.value}').join(' · ');

class _RoundCard extends StatelessWidget {
  const _RoundCard({required this.round});
  final DeliveryRound round;

  @override
  Widget build(BuildContext context) {
    final r = round;
    final arrivals = r.arrivals;
    final pending = r.stops.where((o) => o.status == 'pending').length;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r.isPickup ? 'ลูกค้ามารับ' : 'รอบส่ง'} ${slotLabel(r.time)} น.'
              '${r.stops.length > 1 ? ' · รวม ${r.stops.length} บ้าน' : ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  avatar: const Icon(Icons.soup_kitchen, size: 18),
                  label: Text('เริ่มทำ ${hhmm(r.startCooking)} น.'),
                  visualDensity: VisualDensity.compact,
                ),
                if (!r.isPickup)
                  Chip(
                    avatar: const Icon(Icons.delivery_dining, size: 18),
                    label: Text('ออกจากร้าน ${hhmm(r.leaveShop)} น.'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (pending > 0)
                  Chip(
                    backgroundColor: Colors.orange.shade100,
                    label: Text('ยังไม่กดรับ $pending ออเดอร์'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            Text('ทำ: ${_dishText(r.dishes)}'),
            const Divider(),
            for (final (i, o) in r.stops.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${r.stops.length > 1 ? '${i + 1}. ' : ''}#${o.shortId}'
                  '${(o.addressNote ?? '').isEmpty ? '' : ' · ${o.addressNote}'}'
                  '${r.isPickup ? '' : ' · ถึงราว ${hhmm(arrivals[i])} น.'}'
                  '${o.hasDropoff || r.isPickup ? '' : ' · ไม่มีหมุด'}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
