import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/labels.dart';
import '../widgets/common.dart';
import '../widgets/food_animation.dart';
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

  static String? _greetedUid;

  /// Says who is signed in, once per sign-in, so it is clear which account is in use.
  /// A brand-new customer gets the welcome message instead.
  void _greet(BuildContext context, Map<String, dynamic>? profile) {
    if (profile == null || _greetedUid == Api.uid) return;
    _greetedUid = Api.uid;
    if (Api.justJoined) return;
    final messenger = ScaffoldMessenger.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'สวัสดีคุณ ${profile['full_name'] ?? ''} · เข้าสู่ระบบเป็น${roleLabel[profile['role']] ?? 'สมาชิก'}',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Loader<(Map<String, dynamic>?, bool)>(
      load: _load,
      builder: (context, data, _) {
        final (profile, hasApplication) = data;
        _greet(context, profile);
        return switch (profile?['role']) {
          'admin' => const AdminScreen(),
          'shop_owner' => const ShopHome(),
          _ when hasApplication || Api.signupAs == 'shop' => const ShopApplyScreen(asHome: true),
          _ when Api.signupAs == 'rider' => const RiderScreen(asHome: true),
          _ => const _Welcome(child: CustomerHome()),
        };
      },
    ),
  );
}

/// Greets a customer once, right after they sign up.
class _Welcome extends StatefulWidget {
  const _Welcome({required this.child});
  final Widget child;

  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome> {
  @override
  void initState() {
    super.initState();
    if (!Api.justJoined) return;
    Api.justJoined = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(context: context, builder: (_) => const WelcomeDialog());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const FoodAnimation(),
    title: const Text('ยินดีต้อนรับ', textAlign: TextAlign.center),
    content: const Text(
      'คุณเป็นสมาชิก ส่งอาหารบ้านดุง แล้ว\nสามารถสั่งอาหารได้แล้วค่ะ\nทานให้อร่อยทุกเมนูนะคะ',
      textAlign: TextAlign.center,
    ),
    actionsAlignment: MainAxisAlignment.center,
    actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
  );
}

/// Step-by-step guide for shops, published with the web app (web/manual/shop.html).
const shopManualUrl = 'https://cozy-melomakarona-cafbc6.netlify.app/manual/shop.html';

/// The Android app, published by the Android APK workflow as the "latest" GitHub release (free to download,
/// so it doesn't use Netlify credits).
const androidApkUrl =
    'https://github.com/laksanac61-oss/village-food-app/releases/download/latest/ban-dung.apk';

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
        const _AccountHeader(),
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
          leading: const Icon(Icons.menu_book),
          title: const Text('คู่มือร้านค้า'),
          onTap: () {
            Navigator.pop(context);
            launchUrl(Uri.parse(shopManualUrl));
          },
        ),
        if (kIsWeb)
          ListTile(
            leading: const Icon(Icons.android),
            title: const Text('ดาวน์โหลดแอป Android'),
            onTap: () {
              Navigator.pop(context);
              launchUrl(Uri.parse(androidApkUrl));
            },
          ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('ออกจากระบบ'),
          onTap: () {
            Navigator.pop(context);
            HomeRouter._greetedUid = null;
            Api.signOut();
          },
        ),
      ],
    ),
  );
}

/// Top of the drawer: who is signed in, and as what.
class _AccountHeader extends StatelessWidget {
  const _AccountHeader();

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: Api.myProfile(),
    builder: (context, snap) {
      final p = snap.data;
      final name = (p?['full_name'] as String?)?.trim() ?? '';
      final phone = (p?['phone'] as String?) ?? '';
      final role = roleLabel[p?['role']];
      final scheme = Theme.of(context).colorScheme;
      return UserAccountsDrawerHeader(
        decoration: BoxDecoration(color: scheme.primary),
        currentAccountPicture: CircleAvatar(
          backgroundColor: scheme.onPrimary,
          child: Text(
            name.isEmpty ? '?' : name.characters.first,
            style: TextStyle(fontSize: 28, color: scheme.primary),
          ),
        ),
        accountName: Row(
          children: [
            Flexible(child: Text(name.isEmpty ? 'ส่งอาหารบ้านดุง' : name, overflow: TextOverflow.ellipsis)),
            if (role != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: scheme.onPrimary, borderRadius: BorderRadius.circular(12)),
                child: Text(role, style: TextStyle(fontSize: 12, color: scheme.primary)),
              ),
            ],
          ],
        ),
        accountEmail: Text(phone.isNotEmpty ? 'โทร ${phoneLabel(phone)}' : Api.email ?? ''),
      );
    },
  );
}
