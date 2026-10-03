import 'package:flutter/material.dart';

import '../core/api.dart';
import '../widgets/common.dart';
import 'admin/admin_screen.dart';
import 'customer/customer_home.dart';
import 'rider/rider_screen.dart';
import 'shop/shop_home.dart';

/// Picks the home screen for the signed-in user's role. Everyone can also
/// use the customer side; riders reach their screen from the menu.
class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Loader<Map<String, dynamic>?>(
      load: Api.myProfile,
      builder: (context, profile, _) => switch (profile?['role']) {
        'admin' => const AdminScreen(),
        'shop_owner' => const ShopHome(),
        _ => const CustomerHome(),
      },
    ),
  );
}

/// Drawer shared by every role's home screen.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => Drawer(
    child: ListView(
      children: [
        const DrawerHeader(child: Text('ส่งอาหารบ้านดุง', style: TextStyle(fontSize: 20))),
        ListTile(
          leading: const Icon(Icons.storefront),
          title: const Text('สั่งอาหาร'),
          onTap: () => _open(context, const CustomerHome()),
        ),
        ListTile(
          leading: const Icon(Icons.delivery_dining),
          title: const Text('ไรเดอร์ (รับงานส่ง)'),
          onTap: () => _open(context, const RiderScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('ออกจากระบบ'),
          onTap: () {
            Navigator.pop(context);
            Api.signOut();
          },
        ),
      ],
    ),
  );
}
