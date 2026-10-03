import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../widgets/common.dart';
import '../home_router.dart';
import 'shop_form.dart';
import 'shop_home.dart';

/// A member's request to open a shop: the form first, then where the review stands.
class ShopApplyScreen extends StatefulWidget {
  const ShopApplyScreen({super.key, this.asHome = false});

  /// True when this is the member's first screen (they picked "shop" at sign-up).
  final bool asHome;

  @override
  State<ShopApplyScreen> createState() => _ShopApplyScreenState();
}

class _ShopApplyScreenState extends State<ShopApplyScreen> {
  bool _editing = false;

  Future<(Shop?, Map<String, dynamic>?)> _load() async => (await Api.myShop(), await Api.myProfile());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('สมัครเปิดร้าน')),
    drawer: widget.asHome ? const AppDrawer() : null,
    body: Loader<(Shop?, Map<String, dynamic>?)>(
      load: _load,
      builder: (context, data, reload) {
        final (shop, profile) = data;
        if (shop == null || _editing) {
          return ShopForm(
            shop: shop,
            defaultPhone: profile?['phone'],
            requireDetails: true,
            submitLabel: shop == null ? 'ส่งคำขอเปิดร้าน' : 'ส่งข้อมูลให้ตรวจอีกครั้ง',
            onSubmit: (fields) async {
              if (shop == null) {
                await Api.applyForShop(fields);
              } else {
                await Api.resubmitShop(shop.id, fields);
              }
              if (!mounted) return;
              setState(() => _editing = false);
              reload();
            },
          );
        }
        return _Status(shop: shop, asHome: widget.asHome, onEdit: () => setState(() => _editing = true));
      },
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.shop, required this.asHome, required this.onEdit});
  final Shop shop;
  final bool asHome;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, Color color, String title, String body) = switch (shop.status) {
      'approved' => (
        Icons.verified,
        Colors.green,
        'ร้านของคุณได้รับอนุมัติแล้ว 🎉',
        'เข้าหน้าร้านเพื่อเพิ่มเมนูและเปิดรับออเดอร์ได้เลย',
      ),
      'rejected' => (
        Icons.error_outline,
        Colors.red,
        'คำขอยังไม่ผ่านการอนุมัติ',
        'แก้ไขข้อมูลตามที่ผู้ดูแลแจ้ง แล้วกดส่งใหม่ได้เลย',
      ),
      _ => (
        Icons.hourglass_top,
        Colors.orange,
        'ส่งคำขอแล้ว รอผู้ดูแลตรวจสอบ',
        'เมื่ออนุมัติแล้ว หน้านี้จะเปลี่ยนเป็นหน้าร้านของคุณ ดึงหน้าจอลงเพื่อเช็กสถานะล่าสุด',
      ),
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Icon(icon, size: 64, color: color),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(body, textAlign: TextAlign.center),
        if (shop.isRejected && (shop.reviewNote ?? '').isNotEmpty)
          Card(
            color: theme.colorScheme.errorContainer,
            margin: const EdgeInsets.only(top: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('เหตุผลจากผู้ดูแล: ${shop.reviewNote}'),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (shop.coverUrl != null)
                AspectRatio(aspectRatio: 16 / 9, child: NetPhoto(shop.coverUrl!, zoomable: true)),
              ListTile(
                leading: LogoAvatar(shop.imageUrl, radius: 24, zoomable: true),
                title: Text(shop.name),
                subtitle: Text(
                  [
                    shop.category,
                    shop.openingHours,
                    shop.address,
                  ].whereType<String>().where((s) => s.isNotEmpty).join('\n'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (shop.isApproved)
          FilledButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopHome())),
            child: const Text('ไปหน้าร้านของฉัน'),
          )
        else if (shop.isRejected)
          FilledButton(onPressed: onEdit, child: const Text('แก้ไขแล้วส่งใหม่'))
        else
          OutlinedButton(onPressed: onEdit, child: const Text('แก้ไขข้อมูล')),
        if (asHome && !shop.isApproved) ...[
          const SizedBox(height: 16),
          const Text('ระหว่างรอ คุณยังสั่งอาหารได้ตามปกติ ที่เมนู ☰ มุมซ้ายบน', textAlign: TextAlign.center),
        ],
      ],
    );
  }
}
