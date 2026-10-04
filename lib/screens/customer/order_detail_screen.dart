import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../widgets/common.dart';
import '../../widgets/order_card.dart';
import '../../widgets/maps.dart';
import '../../widgets/promptpay_qr.dart';
import '../../widgets/stars.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  Future<(Order, Shop, Map<String, dynamic>?, String?)> _load() async {
    final o = await Api.order(orderId);
    final shop = await Api.shop(o.shopId);
    final rider = o.riderId == null ? null : await Api.riderPublic(o.riderId!);
    final riderPay = o.riderId == null || o.deliveryPaymentMethod != 'promptpay'
        ? null
        : await Api.riderPromptPay(o.riderId!);
    return (o, shop, rider, riderPay);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('รายละเอียดออเดอร์')),
    body: Loader(
      load: _load,
      reloadOn: Api.orderChanges(),
      builder: (context, data, reload) {
        final (o, shop, rider, riderPay) = data;
        final needsFoodPayment =
            o.foodPaymentMethod == 'promptpay' &&
            (o.foodPaymentStatus == 'unpaid' || o.foodPaymentStatus == 'rejected') &&
            !o.isClosed;
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            OrderCard(order: o, title: shop.name),
            if (o.status == 'completed') _RateCard(order: o, shopName: shop.name),
            if (o.isDelivery && !o.isClosed) _MapSection(order: o, onChanged: reload),
            if (o.foodPaymentStatus == 'rejected')
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'ร้านแจ้งว่าสลิปไม่ถูกต้อง กรุณาตรวจสอบและส่งสลิปใหม่',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            if (needsFoodPayment) ...[
              const SizedBox(height: 12),
              PromptPayQr(target: shop.promptpayId, amount: o.foodTotal, payee: shop.name),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  icon: const Icon(Icons.upload),
                  label: const Text('แนบสลิปการโอน'),
                  onPressed: () async {
                    final bytes = await pickPhoto();
                    if (bytes == null || !context.mounted) return;
                    if (await guard(
                      context,
                      () => Api.uploadSlip(o.id, bytes),
                      done: 'ส่งสลิปแล้ว รอร้านตรวจสอบ',
                    )) {
                      reload();
                    }
                  },
                ),
              ),
            ],
            if (rider != null)
              ListTile(
                leading: const Icon(Icons.delivery_dining),
                title: Text('ไรเดอร์: ${rider['full_name'] ?? '-'}'),
                subtitle: Text('โทร ${rider['phone'] ?? '-'}'),
              ),
            if (riderPay != null && !o.isClosed) ...[
              const SizedBox(height: 12),
              PromptPayQr(target: riderPay, amount: o.deliveryFee, payee: 'ไรเดอร์ (ค่าส่ง)'),
            ],
            if (o.status == 'pending')
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: () async {
                    if (await guard(
                      context,
                      () => Api.setStatus(o.id, 'cancelled'),
                      done: 'ยกเลิกออเดอร์แล้ว',
                    )) {
                      reload();
                    }
                  },
                  child: const Text('ยกเลิกออเดอร์'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'สถานะ: ${orderStatusLabel[o.status]}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _MapSection extends StatelessWidget {
  const _MapSection({required this.order, required this.onChanged});
  final Order order;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final rider = o.hasRiderLocation && o.isOnTheWay ? LatLng(o.riderLat!, o.riderLng!) : null;
    final dropoff = o.hasDropoff ? LatLng(o.dropoffLat!, o.dropoffLng!) : null;
    final age = o.riderLocAt == null ? null : DateTime.now().difference(o.riderLocAt!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderMap(dropoff: dropoff, rider: rider),
          if (rider != null && age != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                age.inMinutes >= 2
                    ? 'ตำแหน่งไรเดอร์ล่าสุดเมื่อ ${age.inMinutes} นาทีที่แล้ว'
                    : 'ตำแหน่งไรเดอร์อัปเดตสด',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          if (rider == null && o.riderId != null && o.isOnTheWay)
            const Text(
              'จะเห็นตำแหน่งไรเดอร์เมื่อไรเดอร์เริ่มออกเดินทาง',
              style: TextStyle(color: Colors.grey),
            ),
          if (dropoff == null)
            OutlinedButton.icon(
              icon: const Icon(Icons.location_on),
              label: const Text('ปักหมุดบ้านให้ไรเดอร์'),
              onPressed: () async {
                final p = await Navigator.push<LatLng>(
                  context,
                  MaterialPageRoute(builder: (_) => const PinPickerScreen()),
                );
                if (p == null || !context.mounted) return;
                if (await guard(context, () => Api.setDropoff(o.id, p.latitude, p.longitude))) onChanged();
              },
            ),
        ],
      ),
    );
  }
}

/// After the food arrives, the customer gives the shop 1-5 stars and an optional short review.
class _RateCard extends StatefulWidget {
  const _RateCard({required this.order, required this.shopName});
  final Order order;
  final String shopName;

  @override
  State<_RateCard> createState() => _RateCardState();
}

class _RateCardState extends State<_RateCard> {
  final _comment = TextEditingController();
  int _stars = 0;
  bool _saved = false;
  bool _editing = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Api.myReview(widget.order.id).then((r) {
      if (r == null || !mounted) return;
      setState(() {
        _stars = r['stars'] as int;
        _comment.text = r['comment'] ?? '';
        _saved = true;
      });
    }, onError: (_) {});
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    final ok = await guard(
      context,
      () => Api.rateOrder(widget.order.id, _stars, _comment.text.trim()),
      done: 'ขอบคุณสำหรับรีวิวค่ะ',
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _saved = true;
        _editing = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_saved && !_editing) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Row(children: [const Text('คุณให้ '), Stars(_stars.toDouble())]),
          subtitle: _comment.text.isEmpty ? null : Text(_comment.text),
          trailing: TextButton(onPressed: () => setState(() => _editing = true), child: const Text('แก้ไข')),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              'อาหารจาก ${widget.shopName} เป็นอย่างไรบ้างคะ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            StarPicker(value: _stars, onChanged: (v) => setState(() => _stars = v)),
            if (_stars > 0) ...[
              Text(
                starWords[_stars]!,
                style: const TextStyle(color: starColor, fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: _comment,
                maxLength: 300,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'เล่าให้ร้านฟังหน่อย (ไม่ใส่ก็ได้)'),
              ),
              FilledButton(onPressed: _busy ? null : _send, child: const Text('ส่งรีวิว')),
            ],
          ],
        ),
      ),
    );
  }
}
