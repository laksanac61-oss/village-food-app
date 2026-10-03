import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/labels.dart';
import '../../core/location.dart';
import '../../core/models.dart';
import '../../widgets/common.dart';
import '../../widgets/maps.dart';
import '../../widgets/promptpay_qr.dart';

/// Admin checks a shop application in full and approves or rejects it.
class ShopReviewScreen extends StatelessWidget {
  const ShopReviewScreen({super.key, required this.shopId});
  final String shopId;

  Future<void> _approve(BuildContext context, Shop shop) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('อนุมัติร้านนี้?'),
        content: Text('"${shop.name}" จะแสดงให้ลูกค้าเห็นเมื่อเจ้าของร้านเพิ่มเมนูและกดเปิดร้าน'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('อนุมัติ')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (await guard(context, () => Api.reviewShop(shop.id, true, null), done: 'อนุมัติร้านแล้ว') &&
        context.mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _reject(BuildContext context, Shop shop) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ไม่อนุมัติ'),
        content: TextField(
          controller: reason,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'บอกเหตุผลให้เจ้าของร้านแก้ไข',
            hintText: 'เช่น รูปหน้าร้านไม่ชัด ขอรูปใหม่',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () {
              if (reason.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('ส่งกลับให้แก้ไข'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (await guard(
          context,
          () => Api.reviewShop(shop.id, false, reason.text.trim()),
          done: 'ส่งกลับให้แก้ไขแล้ว',
        ) &&
        context.mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ตรวจสอบร้าน')),
    body: Loader<(Shop, Map<String, dynamic>?)>(
      load: () => Api.shopForReview(shopId),
      builder: (context, data, _) {
        final (shop, owner) = data;
        final loc = shop.location;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (shop.coverUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(shop.coverUrl!, fit: BoxFit.cover),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 28,
                backgroundImage: shop.imageUrl == null ? null : NetworkImage(shop.imageUrl!),
                child: shop.imageUrl == null ? const Icon(Icons.store) : null,
              ),
              title: Text(shop.name, style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text('${shop.category ?? '-'} · ${shopStatusLabel[shop.status] ?? shop.status}'),
            ),
            if ((shop.description ?? '').isNotEmpty) Text(shop.description!),
            const Divider(height: 24),
            _Row('เจ้าของร้าน', '${owner?['full_name'] ?? '-'} · ${owner?['phone'] ?? '-'}'),
            _Row('เบอร์โทรร้าน', shop.phone ?? '-'),
            _Row('เวลาเปิด-ปิด', shop.openingHours ?? '-'),
            _Row('ที่อยู่ / จุดสังเกต', shop.address ?? '-'),
            _Row('รับเงินสด', shop.acceptsCash ? 'รับ' : 'ไม่รับ'),
            if ((shop.phone ?? '').isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.call),
                  label: const Text('โทรหาร้าน'),
                  onPressed: () => launchUrl(Uri.parse('tel:${shop.phone}')),
                ),
              ),
            const Divider(height: 24),
            Text('ตำแหน่งร้าน', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (loc == null)
              const Text('ยังไม่ได้ปักหมุด')
            else ...[
              OrderMap(shop: loc, height: 200),
              TextButton.icon(
                icon: const Icon(Icons.map),
                label: const Text('เปิดใน Google Maps'),
                onPressed: () => launchUrl(placeUrl(loc.latitude, loc.longitude)),
              ),
            ],
            const Divider(height: 24),
            Text('ตรวจพร้อมเพย์', style: Theme.of(context).textTheme.titleMedium),
            const Text(
              'สแกนด้วยแอปธนาคารเพื่อดูชื่อเจ้าของบัญชีว่าตรงกับร้าน (ดูชื่อแล้วกดยกเลิก ไม่ต้องโอน)',
            ),
            const SizedBox(height: 8),
            PromptPayQr(target: shop.promptpayId, amount: 1, payee: shop.name),
            if (shop.isRejected && (shop.reviewNote ?? '').isNotEmpty) ...[
              const Divider(height: 24),
              Text('เหตุผลที่ส่งกลับครั้งก่อน: ${shop.reviewNote}'),
            ],
            const SizedBox(height: 24),
            if (!shop.isApproved) ...[
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('อนุมัติร้าน'),
                onPressed: () => _approve(context, shop),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('ไม่อนุมัติ / ส่งกลับให้แก้ไข'),
                onPressed: () => _reject(context, shop),
              ),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
