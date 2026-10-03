import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../widgets/common.dart';
import '../../widgets/order_card.dart';
import '../home_router.dart';
import 'order_detail_screen.dart';
import 'shop_menu_screen.dart';

class CustomerHome extends StatelessWidget {
  const CustomerHome({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('ส่งอาหารบ้านดุง'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'ร้านอาหาร'),
            Tab(text: 'ออเดอร์ของฉัน'),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: TabBarView(
        children: [
          Loader<List<Shop>>(
            load: Api.openShops,
            builder: (context, shops, _) => shops.isEmpty
                ? const Empty('ยังไม่มีร้านค้า')
                : ListView(children: [for (final s in shops) _ShopTile(s)]),
          ),
          Loader<List<Order>>(
            load: Api.myOrders,
            reloadOn: Api.orderChanges(),
            builder: (context, orders, _) => orders.isEmpty
                ? const Empty('ยังไม่มีออเดอร์')
                : ListView(
                    children: [
                      for (final o in orders)
                        OrderCard(
                          order: o,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id)),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}

class _ShopTile extends StatelessWidget {
  const _ShopTile(this.shop);
  final Shop shop;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      backgroundImage: shop.imageUrl == null ? null : NetworkImage(shop.imageUrl!),
      child: shop.imageUrl == null ? const Icon(Icons.restaurant) : null,
    ),
    title: Text(shop.name),
    subtitle: Text(shop.isOpen ? (shop.description ?? 'เปิดอยู่') : 'ปิดอยู่'),
    enabled: shop.isOpen,
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopMenuScreen(shop: shop))),
  );
}
