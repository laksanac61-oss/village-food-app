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

  @override
  Widget build(BuildContext context) => Loader<Shop?>(
    load: Api.myShop,
    builder: (context, shop, reload) {
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
          body: TabBarView(
            children: [
              ShopOrders(shop: shop),
              ShopMenuAdmin(shop: shop),
              ShopSettings(shop: shop, onSaved: reload),
            ],
          ),
        ),
      );
    },
  );
}
