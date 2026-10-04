import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../widgets/busy.dart';
import '../../widgets/common.dart';
import '../../widgets/video.dart';
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
        title: _Title(name: Api.myName),
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

/// App name with a hello to the signed-in customer underneath, so they know whose account it is.
class _Title extends StatelessWidget {
  const _Title({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) return const Text('ส่งอาหารบ้านดุง');
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('ส่งอาหารบ้านดุง'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_circle, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'สวัสดี คุณ$name',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile(this.shop);
  final Shop shop;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: LogoAvatar(shop.imageUrl),
    title: Row(
      children: [
        Flexible(child: Text(shop.name, overflow: TextOverflow.ellipsis)),
        if (shop.isOpen && shop.isBusy) ...[const SizedBox(width: 6), const BusyTag()],
      ],
    ),
    subtitle: Text(
      [
        shop.category,
        shop.isOpen
            ? (shop.isBusy ? 'เปิดอยู่ · ไรเดอร์ติดงาน ส่งช้า' : 'เปิดอยู่')
            : (shop.acceptsPreorder ? 'ปิดอยู่ · จองล่วงหน้าได้' : 'ปิดอยู่'),
        shop.openingHours,
      ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
    ),
    trailing: shop.videoUrl == null
        ? null
        : IconButton(
            icon: const Icon(Icons.play_circle, color: Colors.red),
            tooltip: 'ดูวิดีโอแนะนำร้าน',
            onPressed: () => showVideo(context, shop.videoUrl!, title: shop.name),
          ),
    enabled: shop.canOrder,
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopMenuScreen(shop: shop))),
  );
}
