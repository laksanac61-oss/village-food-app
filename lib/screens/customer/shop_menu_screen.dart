import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../widgets/busy.dart';
import '../../widgets/common.dart';
import '../../widgets/food_photo.dart';
import '../../widgets/stars.dart';
import '../../widgets/video.dart';
import 'checkout_screen.dart';

class ShopMenuScreen extends StatelessWidget {
  const ShopMenuScreen({super.key, required this.shop, this.rating});
  final Shop shop;
  final ShopRating? rating;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(shop.name)),
    body: Loader<List<MenuItem>>(
      load: () => Api.menu(shop.id),
      builder: (context, menu, _) => menu.isEmpty
          ? const Empty('ร้านนี้ยังไม่มีเมนู')
          : MenuPicker(
              shop: shop,
              menu: menu,
              header: _ShopHeader(shop, rating),
              onConfirm: (cart) => Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => CheckoutScreen(shop: shop, cart: cart),
                ),
              ),
            ),
    ),
  );
}

/// The menu as large photo cards: tap a photo to add it, then confirm to see the summary with prices.
class MenuPicker extends StatefulWidget {
  const MenuPicker({super.key, required this.shop, required this.menu, required this.onConfirm, this.header});
  final Shop shop;
  final List<MenuItem> menu;
  final Widget? header;

  /// Opens checkout with the chosen lines; returns true when the order was placed.
  final Future<bool?> Function(List<CartLine> cart) onConfirm;

  @override
  State<MenuPicker> createState() => _MenuPickerState();
}

class _MenuPickerState extends State<MenuPicker> {
  final Map<String, CartLine> _cart = {};

  double get _total => _cart.values.fold(0, (s, l) => s + l.item.price * l.qty);
  int get _count => _cart.values.fold(0, (s, l) => s + l.qty);
  int _qty(MenuItem m) => _cart[m.id]?.qty ?? 0;

  void _add(MenuItem m) =>
      setState(() => _cart.update(m.id, (l) => l..qty += 1, ifAbsent: () => CartLine(m)));

  void _remove(MenuItem m) => setState(() {
    final l = _cart[m.id];
    if (l == null) return;
    if (--l.qty == 0) _cart.remove(m.id);
  });

  Future<void> _summary() async {
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => _Summary(
          lines: _cart.values.toList(),
          total: _total,
          onAdd: (m) => refresh(() => _add(m)),
          onRemove: (m) {
            refresh(() => _remove(m));
            if (_cart.isEmpty) Navigator.pop(ctx);
          },
        ),
      ),
    );
    if (go != true || !mounted) return;
    final placed = await widget.onConfirm(_cart.values.toList());
    if (placed == true && mounted) setState(_cart.clear);
  }

  @override
  Widget build(BuildContext context) {
    final featured = widget.menu.where((m) => m.isAvailable && m.imageUrl != null).take(6).toList();
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              if (widget.header != null) SliverToBoxAdapter(child: widget.header),
              if (!widget.shop.isOpen)
                const SliverToBoxAdapter(
                  child: ListTile(
                    leading: Icon(Icons.schedule),
                    title: Text('ร้านปิดอยู่ตอนนี้'),
                    subtitle: Text('เลือกเมนูแล้วจองเวลารับอาหารล่วงหน้าได้'),
                  ),
                ),
              if (featured.length >= 2) ...[
                const SliverToBoxAdapter(child: _Heading('เมนูแนะนำ')),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 210,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: featured.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => SizedBox(
                        width: 280,
                        child: _FeaturedCard(
                          item: featured[i],
                          qty: _qty(featured[i]),
                          onAdd: () => _add(featured[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: _Heading('เมนูทั้งหมด')),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: widget.menu.length,
                  itemBuilder: (_, i) {
                    final m = widget.menu[i];
                    return _MenuCard(item: m, qty: _qty(m), onAdd: () => _add(m), onRemove: () => _remove(m));
                  },
                ),
              ),
            ],
          ),
        ),
        if (_cart.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: const Icon(Icons.check_circle),
                  onPressed: _summary,
                  label: Text('ยืนยันรายการ ($_count) · ${baht(_total)}'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
  );
}

/// Green bubble with how many of a dish are in the cart.
class _QtyBadge extends StatelessWidget {
  const _QtyBadge(this.qty);
  final int qty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(20)),
      child: Text(
        '×$qty',
        style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Round button laid over a photo.
class _PhotoButton extends StatelessWidget {
  const _PhotoButton({required this.icon, required this.onPressed, required this.tooltip});
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: scheme.primary),
        onPressed: onPressed,
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.item, required this.qty, required this.onAdd, required this.onRemove});
  final MenuItem item;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soldOut = !item.isAvailable;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: qty > 0 ? BorderSide(color: theme.colorScheme.primary, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: soldOut ? null : onAdd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FoodPhoto(item.imageUrl),
                  if (soldOut)
                    const ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: Text(
                          'หมด',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (qty > 0) Positioned(top: 8, right: 8, child: _QtyBadge(qty)),
                  if (qty > 0)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: _PhotoButton(icon: Icons.remove, tooltip: 'ลดจำนวน', onPressed: onRemove),
                    ),
                  if (!soldOut)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: _PhotoButton(icon: Icons.add, tooltip: 'เพิ่ม', onPressed: onAdd),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if ((item.description ?? '').isNotEmpty)
                    Text(
                      item.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    baht(item.price),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
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
}

/// Wide photo card in the "เมนูแนะนำ" row, like a banner.
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.item, required this.qty, required this.onAdd});
  final MenuItem item;
  final int qty;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: InkWell(
      onTap: onAdd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FoodPhoto(item.imageUrl),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
                stops: [0.45, 1],
              ),
            ),
          ),
          if (qty > 0) Positioned(top: 10, right: 10, child: _QtyBadge(qty)),
          Positioned(
            left: 14,
            right: 60,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  baht(item.price),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: _PhotoButton(icon: Icons.add, tooltip: 'เพิ่ม', onPressed: onAdd),
          ),
        ],
      ),
    ),
  );
}

/// What the customer picked, with prices, before going to checkout. Pops true to continue.
class _Summary extends StatelessWidget {
  const _Summary({required this.lines, required this.total, required this.onAdd, required this.onRemove});
  final List<CartLine> lines;
  final double total;
  final void Function(MenuItem) onAdd;
  final void Function(MenuItem) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('สรุปรายการอาหาร', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final l in lines)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(width: 52, height: 52, child: FoodPhoto(l.item.imageUrl)),
                      ),
                      title: Text(l.item.name),
                      subtitle: Text('${baht(l.item.price)} × ${l.qty} = ${baht(l.item.price * l.qty)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'ลดจำนวน',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => onRemove(l.item),
                          ),
                          Text('${l.qty}', style: theme.textTheme.titleMedium),
                          IconButton(
                            tooltip: 'เพิ่ม',
                            icon: const Icon(Icons.add_circle),
                            onPressed: () => onAdd(l.item),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(child: Text('รวมค่าอาหาร', style: theme.textTheme.titleMedium)),
                Text(
                  baht(total),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text('ค่าส่งคิดในขั้นตอนถัดไป', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('เลือกเพิ่ม'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('ยืนยัน ไปชำระเงิน'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Storefront photo and basic details above the menu.
class _ShopHeader extends StatelessWidget {
  const _ShopHeader(this.shop, this.rating);
  final Shop shop;
  final ShopRating? rating;

  @override
  Widget build(BuildContext context) {
    final details = [
      shop.category,
      shop.description,
      if ((shop.openingHours ?? '').isNotEmpty) 'เวลาเปิด ${shop.openingHours}',
      shop.address,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    if (shop.coverUrl == null && details.isEmpty && shop.videoUrl == null && !shop.isBusy && rating == null) {
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
        if (rating != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
            child: Row(
              children: [
                Expanded(child: ShopRatingLine(rating!)),
                if (rating!.reviews > 0)
                  TextButton(onPressed: () => showReviews(context, shop), child: const Text('ดูรีวิว')),
              ],
            ),
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
