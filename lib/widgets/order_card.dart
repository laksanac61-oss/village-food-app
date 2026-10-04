import 'package:flutter/material.dart';

import '../core/labels.dart';
import '../core/models.dart';
import '../core/schedule.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.title, this.onTap, this.actions = const []});

  final Order order;
  final String? title;
  final VoidCallback? onTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final t = o.createdAt;
    final time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title ?? 'ออเดอร์ #${o.shortId}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(time, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              if (o.scheduledFor != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Chip(
                    avatar: const Icon(Icons.event_available, size: 18),
                    label: Text('จองรับ ${slotLabel(o.scheduledFor!)} น.'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                orderStatusLabel[o.status] ?? o.status,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 4),
              for (final l in o.items)
                Text('${l.qty} × ${l.name}${(l.note ?? '').isEmpty ? '' : ' (${l.note})'}'),
              const SizedBox(height: 4),
              Text(
                'ค่าอาหาร ${baht(o.foodTotal)} · ${paymentMethodLabel[o.foodPaymentMethod]}'
                ' · ${paymentStatusLabel[o.foodPaymentStatus]}',
              ),
              Text(
                o.isDelivery
                    ? 'ส่งถึงบ้าน · ค่าส่ง ${baht(o.deliveryFee)} (${paymentMethodLabel[o.deliveryPaymentMethod]})'
                    : 'รับเองที่ร้าน',
              ),
              if ((o.addressNote ?? '').isNotEmpty) Text('ที่อยู่: ${o.addressNote}'),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
