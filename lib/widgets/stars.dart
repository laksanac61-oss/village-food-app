import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/models.dart';

const starColor = Color(0xFFF5A623);

/// Five stars filled to [value] (halves shown), e.g. 4.5.
class Stars extends StatelessWidget {
  const Stars(this.value, {super.key, this.size = 16});
  final double value;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          value >= i
              ? Icons.star
              : value >= i - 0.5
              ? Icons.star_half
              : Icons.star_border,
          size: size,
          color: starColor,
        ),
    ],
  );
}

/// "★★★★½ 4.6 (23) · สั่งแล้ว 120 ครั้ง", or "ร้านใหม่" before anyone has rated it.
class ShopRatingLine extends StatelessWidget {
  const ShopRatingLine(this.rating, {super.key});
  final ShopRating rating;

  @override
  Widget build(BuildContext context) {
    final grey = TextStyle(color: Colors.grey.shade700, fontSize: 13);
    final stars = rating.stars;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        if (stars != null) ...[
          Stars(stars),
          Text(
            '${stars.toStringAsFixed(1)} (${rating.reviews})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ] else
          Text('ยังไม่มีรีวิว', style: grey),
        if (rating.orders > 0) Text('· สั่งแล้ว ${rating.orders} ครั้ง', style: grey),
      ],
    );
  }
}

/// Tappable stars for rating an order.
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 1; i <= 5; i++)
        IconButton(
          iconSize: 40,
          tooltip: '$i ดาว',
          icon: Icon(i <= value ? Icons.star : Icons.star_border, color: starColor),
          onPressed: () => onChanged(i),
        ),
    ],
  );
}

const starWords = {1: 'ต้องปรับปรุง', 2: 'พอใช้', 3: 'ดี', 4: 'ดีมาก', 5: 'ยอดเยี่ยม'};

/// Latest customer comments for a shop, without names.
Future<void> showReviews(BuildContext context, Shop shop) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (ctx) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.6,
    builder: (ctx, scroll) => FutureBuilder<List<Map<String, dynamic>>>(
      future: Api.shopReviews(shop.id),
      builder: (ctx, snap) {
        final reviews = snap.data ?? const [];
        return ListView(
          controller: scroll,
          children: [
            ListTile(title: Text('รีวิว ${shop.name}', style: Theme.of(ctx).textTheme.titleLarge)),
            if (snap.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            for (final r in reviews)
              ListTile(
                title: Stars((r['stars'] as num).toDouble()),
                subtitle: Text(
                  [
                    if ((r['comment'] ?? '').toString().isNotEmpty) r['comment'],
                    _ago(DateTime.parse(r['created_at']).toLocal()),
                  ].join('\n'),
                ),
              ),
          ],
        );
      },
    ),
  ),
);

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inDays >= 30) return '${t.day}/${t.month}/${t.year + 543}';
  if (d.inDays >= 1) return '${d.inDays} วันที่แล้ว';
  if (d.inHours >= 1) return '${d.inHours} ชั่วโมงที่แล้ว';
  return 'เมื่อสักครู่';
}
