import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../widgets/common.dart';
import '../../widgets/order_card.dart';

class ShopOrders extends StatelessWidget {
  const ShopOrders({super.key, required this.shop});
  final Shop shop;

  List<Widget> _actions(BuildContext context, Order o, VoidCallback reload) {
    Widget step(String label, String status, {bool primary = true}) {
      Future<void> onPressed() async {
        if (await guard(context, () => Api.setStatus(o.id, status))) reload();
      }

      return primary
          ? FilledButton(onPressed: onPressed, child: Text(label))
          : OutlinedButton(onPressed: onPressed, child: Text(label));
    }

    return [
      if (o.foodSlipPath != null && o.foodPaymentStatus == 'slip_uploaded') ...[
        OutlinedButton.icon(
          icon: const Icon(Icons.receipt_long),
          label: const Text('ดูสลิป'),
          onPressed: () async {
            final url = await Api.slipUrl(o.foodSlipPath!);
            if (!context.mounted) return;
            showDialog(
              context: context,
              builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(url))),
            );
          },
        ),
        FilledButton.tonal(
          onPressed: () async {
            if (await guard(context, () => Api.reviewPayment(o.id, true))) reload();
          },
          child: const Text('ยืนยันได้รับเงิน'),
        ),
        TextButton(
          onPressed: () async {
            if (await guard(context, () => Api.reviewPayment(o.id, false))) reload();
          },
          child: const Text('สลิปไม่ถูกต้อง'),
        ),
      ],
      if (o.foodPaymentMethod == 'cash' && o.foodPaymentStatus == 'unpaid' && o.status != 'cancelled')
        FilledButton.tonal(
          onPressed: () async {
            if (await guard(context, () => Api.reviewPayment(o.id, true))) reload();
          },
          child: const Text('ได้รับเงินสดแล้ว'),
        ),
      if (o.status == 'pending') ...[
        step('รับออเดอร์', 'accepted'),
        step('ปฏิเสธ', 'cancelled', primary: false),
      ],
      if (o.status == 'accepted') step('เริ่มทำอาหาร', 'cooking'),
      if (o.status == 'cooking' || o.status == 'accepted') step('อาหารพร้อม', 'ready'),
      if (o.status == 'ready' && !o.isDelivery) step('ลูกค้ารับแล้ว', 'completed'),
      if (o.status == 'ready' && o.isDelivery && o.riderId == null)
        const Chip(label: Text('รอไรเดอร์รับงาน')),
    ];
  }

  @override
  Widget build(BuildContext context) => Loader<List<Order>>(
    load: () => Api.shopOrders(shop.id),
    reloadOn: Api.orderChanges(),
    builder: (context, orders, reload) {
      final active = orders.where((o) => !o.isClosed).toList();
      final done = orders.where((o) => o.isClosed).take(20).toList();
      if (orders.isEmpty) return const Empty('ยังไม่มีออเดอร์');
      return ListView(
        children: [
          if (active.isNotEmpty) const _Header('กำลังดำเนินการ'),
          for (final o in active) OrderCard(order: o, actions: _actions(context, o, reload)),
          if (done.isNotEmpty) const _Header('เสร็จแล้ว / ยกเลิก'),
          for (final o in done) OrderCard(order: o),
        ],
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
