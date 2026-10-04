import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../widgets/busy.dart';
import '../../widgets/common.dart';
import '../home_router.dart';
import 'order_alerts.dart';
import 'shop_income.dart';
import 'shop_menu_admin.dart';
import 'shop_orders.dart';
import 'shop_settings.dart';

class ShopHome extends StatelessWidget {
  const ShopHome({super.key});

  Future<(Shop?, int)> _load() async {
    final shop = await Api.myShop();
    return (shop, shop == null ? 0 : await Api.menuCount(shop.id));
  }

  @override
  Widget build(BuildContext context) => Loader<(Shop?, int)>(
    load: _load,
    builder: (context, data, reload) {
      final (shop, menuCount) = data;
      if (shop == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('ร้านของฉัน')),
          drawer: const AppDrawer(),
          body: const Empty('ยังไม่มีร้านที่ผูกกับบัญชีนี้ ติดต่อผู้ดูแลระบบ'),
        );
      }
      return DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: Text(shop.name),
            actions: [
              Row(
                children: [
                  Text(shop.isOpen ? 'เปิดร้าน' : 'ปิดร้าน'),
                  Switch(
                    value: shop.isOpen,
                    onChanged: (v) async {
                      if (await guard(context, () => Api.updateShop(shop.id, {'is_open': v}))) {
                        reload();
                      }
                    },
                  ),
                ],
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'ออเดอร์'),
                Tab(text: 'เมนู'),
                Tab(text: 'รายได้'),
                Tab(text: 'ตั้งค่าร้าน'),
              ],
            ),
          ),
          drawer: const AppDrawer(),
          body: Column(
            children: [
              if (shop.isActive) OrderAlerts(key: ValueKey('alerts-${shop.id}'), shop: shop),
              if (!shop.isActive)
                const MaterialBanner(
                  content: Text('ร้านถูกระงับชั่วคราว ลูกค้าจะมองไม่เห็นร้าน ติดต่อผู้ดูแลระบบ'),
                  leading: Icon(Icons.block, color: Colors.red),
                  actions: [SizedBox.shrink()],
                )
              else if (menuCount == 0 || !shop.isOpen)
                _GettingStarted(hasMenu: menuCount > 0, isOpen: shop.isOpen)
              else
                _BusyBar(shop: shop, onChanged: reload),
              Expanded(
                child: TabBarView(
                  children: [
                    ShopOrders(shop: shop),
                    ShopMenuAdmin(shop: shop, onFirstItem: reload),
                    ShopIncome(shop: shop),
                    ShopSettings(shop: shop, onSaved: reload),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Shown after the admin approves the shop, until it has a menu and is open for orders.
class _GettingStarted extends StatelessWidget {
  const _GettingStarted({required this.hasMenu, required this.isOpen});
  final bool hasMenu;
  final bool isOpen;

  Widget _step(bool done, String text) => Row(
    children: [
      Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? Colors.green : null,
        size: 20,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.all(8),
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasMenu ? 'อีกขั้นเดียว ร้านก็พร้อมขาย' : 'ยินดีด้วย ร้านได้รับอนุมัติแล้ว',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          _step(true, 'ผู้ดูแลอนุมัติร้านแล้ว'),
          _step(hasMenu, 'เพิ่มเมนูพร้อมราคาและรูป ที่แท็บ "เมนู"'),
          _step(isOpen, 'กดสวิตช์ "เปิดร้าน" มุมขวาบน ลูกค้าจะเห็นร้านและสั่งได้ทันที'),
          if (!isOpen) const Text('ปิดสวิตช์เมื่อร้านปิด ลูกค้าจะสั่งไม่ได้จนกว่าจะเปิดอีกครั้ง'),
        ],
      ),
    ),
  );
}

/// Lets an open shop tell customers its deliveries are slow for a while (riders tied up).
class _BusyBar extends StatelessWidget {
  const _BusyBar({required this.shop, required this.onChanged});
  final Shop shop;
  final VoidCallback onChanged;

  Future<void> _start(BuildContext context) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('แจ้งลูกค้าว่าไรเดอร์ติดงาน (busy)'),
              subtitle: Text('ลูกค้าจะเห็นป้ายสีส้ม และเลือกได้ว่าจะรอ ไปรับเอง หรือยกเลิก'),
            ),
            for (final m in const [30, 60, 90, 120])
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('ประมาณ $m นาที'),
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (minutes == null || !context.mounted) return;
    if (await guard(context, () => Api.setShopBusy(shop.id, minutes), done: 'แจ้ง busy แล้ว')) onChanged();
  }

  Future<void> _stop(BuildContext context) async {
    if (await guard(context, () => Api.setShopBusy(shop.id, null), done: 'กลับมาส่งปกติแล้ว')) onChanged();
  }

  @override
  Widget build(BuildContext context) => shop.isBusy
      ? MaterialBanner(
          backgroundColor: Colors.orange.shade50,
          leading: const Icon(Icons.hourglass_top, color: busyColor),
          content: Text('กำลังแจ้งลูกค้าว่า busy ถึง ${hhmm(shop.busyUntil!)} น.'),
          actions: [
            TextButton(onPressed: () => _start(context), child: const Text('เปลี่ยนเวลา')),
            FilledButton(onPressed: () => _stop(context), child: const Text('ส่งได้ปกติแล้ว')),
          ],
        )
      : Padding(
          // full width on the left, where it is seen first on any screen size
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade800,
                side: const BorderSide(color: busyColor),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: const Icon(Icons.hourglass_top),
              label: const Text('ไรเดอร์ติดงาน? กดแจ้งลูกค้าว่าร้าน busy'),
              onPressed: () => _start(context),
            ),
          ),
        );
}
