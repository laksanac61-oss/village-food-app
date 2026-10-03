import 'package:flutter/material.dart';

import '../core/api.dart';
import '../widgets/common.dart';
import 'admin/admin_screen.dart';
import 'customer/customer_home.dart';
import 'rider/rider_screen.dart';
import 'shop/shop_apply.dart';
import 'shop/shop_home.dart';

/// Picks the home screen for the signed-in user's role. Members who asked to
/// open a shop or to ride see that first; everyone can also order from the menu.
class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  Future<(Map<String, dynamic>?, bool)> _load() async {
    final profile = await Api.myProfile();
    // A customer with a shop application (pending or rejected) sees its status first.
    final hasApplication = profile?['role'] == 'customer' && await Api.myShop() != null;
    return (profile, hasApplication);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Loader<(Map<String, dynamic>?, bool)>(
      load: _load,
      builder: (context, data, _) {
        final (profile, hasApplication) = data;
        return switch (profile?['role']) {
          'admin' => const AdminScreen(),
          'shop_owner' => const ShopHome(),
          _ when hasApplication || Api.signupAs == 'shop' => const ShopApplyScreen(asHome: true),
          _ when Api.signupAs == 'rider' => const RiderScreen(asHome: true),
          _ => const CustomerHome(),
        };
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
          leading: const Icon(Icons.add_business),
          title: const Text('สมัครเปิดร้าน'),
          onTap: () => _open(context, const ShopApplyScreen()),
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
