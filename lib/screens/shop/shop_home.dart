import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../widgets/common.dart';
import '../home_router.dart';
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
        length: 3,
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
                Tab(text: 'ตั้งค่าร้าน'),
              ],
            ),
          ),
          drawer: const AppDrawer(),
          body: Column(
            children: [
              if (!shop.isActive)
                const MaterialBanner(
                  content: Text('ร้านถูกระงับชั่วคราว ลูกค้าจะมองไม่เห็นร้าน ติดต่อผู้ดูแลระบบ'),
                  leading: Icon(Icons.block, color: Colors.red),
                  actions: [SizedBox.shrink()],
                )
              else if (menuCount == 0 || !shop.isOpen)
                _GettingStarted(hasMenu: menuCount > 0, isOpen: shop.isOpen),
              Expanded(
                child: TabBarView(
                  children: [
                    ShopOrders(shop: shop),
                    ShopMenuAdmin(shop: shop, onFirstItem: reload),
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
            hasMenu ? 'อีกขั้นเดียว ร้านก็พร้อมขาย' : 'ยินดีด้วย ร้านได้รับอนุมัติแล้ว 🎉',
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
