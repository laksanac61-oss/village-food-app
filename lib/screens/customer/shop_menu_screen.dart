import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../widgets/busy.dart';
import '../../widgets/common.dart';
import '../../widgets/video.dart';
import 'checkout_screen.dart';

class ShopMenuScreen extends StatefulWidget {
  const ShopMenuScreen({super.key, required this.shop});
  final Shop shop;

  @override
  State<ShopMenuScreen> createState() => _ShopMenuScreenState();
}

class _ShopMenuScreenState extends State<ShopMenuScreen> {
  final Map<String, CartLine> _cart = {};

  double get _total => _cart.values.fold(0, (s, l) => s + l.item.price * l.qty);
  int get _count => _cart.values.fold(0, (s, l) => s + l.qty);

  void _add(MenuItem m) =>
      setState(() => _cart.update(m.id, (l) => l..qty += 1, ifAbsent: () => CartLine(m)));

  void _remove(MenuItem m) => setState(() {
    final l = _cart[m.id];
    if (l == null) return;
    if (--l.qty == 0) _cart.remove(m.id);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.shop.name)),
      body: Loader<List<MenuItem>>(
        load: () => Api.menu(widget.shop.id),
        builder: (context, menu, _) => menu.isEmpty
            ? const Empty('ร้านนี้ยังไม่มีเมนู')
            : ListView(
                children: [
                  _ShopHeader(widget.shop),
                  for (final m in menu)
                    ListTile(
                      leading: m.imageUrl == null
                          ? null
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(m.imageUrl!, width: 56, height: 56, fit: BoxFit.cover),
                            ),
                      title: Text(m.name),
                      subtitle: Text(m.isAvailable ? baht(m.price) : 'หมด'),
                      enabled: m.isAvailable,
                      trailing: !m.isAvailable
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_cart.containsKey(m.id)) ...[
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () => _remove(m),
                                  ),
                                  Text('${_cart[m.id]!.qty}'),
                                ],
                                IconButton(icon: const Icon(Icons.add_circle), onPressed: () => _add(m)),
                              ],
                            ),
                    ),
                ],
              ),
      ),
      bottomNavigationBar: _cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: () async {
                    final placed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CheckoutScreen(shop: widget.shop, cart: _cart.values.toList()),
                      ),
                    );
                    if (placed == true) setState(_cart.clear);
                  },
                  child: Text('ดูตะกร้า ($_count รายการ) · ${baht(_total)}'),
                ),
              ),
            ),
    );
  }
}

/// Storefront photo and basic details above the menu.
class _ShopHeader extends StatelessWidget {
  const _ShopHeader(this.shop);
  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final details = [
      shop.category,
      shop.description,
      if ((shop.openingHours ?? '').isNotEmpty) 'เวลาเปิด ${shop.openingHours}',
      shop.address,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    if (shop.coverUrl == null && details.isEmpty && shop.videoUrl == null && !shop.isBusy) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shop.coverUrl != null)
          AspectRatio(aspectRatio: 16 / 9, child: NetPhoto(shop.coverUrl!, zoomable: true)),
        if (shop.isBusy)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: BusyNotice(shop: shop),
          ),
        if (details.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(details.join('\n'))),
        if (shop.videoUrl != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: WatchVideoButton(url: shop.videoUrl!, title: shop.name),
            ),
          ),
        const Divider(),
      ],
    );
  }
}
