import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../widgets/common.dart';
import '../../widgets/order_card.dart';
import '../../widgets/promptpay_qr.dart';

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
