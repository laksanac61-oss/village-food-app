// Plain data classes mapped from Supabase rows.

import 'package:latlong2/latlong.dart';

double _num(dynamic v) => v == null ? 0 : (v as num).toDouble();

class Shop {
  Shop.fromRow(Map<String, dynamic> r)
    : id = r['id'],
      ownerId = r['owner_id'],
      name = r['name'],
      description = r['description'],
      imageUrl = r['image_url'],
      phone = r['phone'],
      promptpayId = r['promptpay_id'],
      acceptsCash = r['accepts_cash'] ?? true,
      isOpen = r['is_open'] ?? false,
      isActive = r['is_active'] ?? true,
      status = r['status'] ?? 'approved',
      reviewNote = r['review_note'],
      category = r['category'],
      address = r['address'],
      lat = (r['lat'] as num?)?.toDouble(),
      lng = (r['lng'] as num?)?.toDouble(),
      coverUrl = r['cover_url'],
      openingHours = r['opening_hours'],
      videoUrl = r['video_url'],
      videoChangesPerDay = r['video_changes_per_day'] ?? 2,
      busyUntil = r['busy_until'] == null ? null : DateTime.parse(r['busy_until']).toLocal(),
      acceptsPreorder = r['accepts_preorder'] ?? true,
      prepMinutes = r['prep_minutes'] ?? 20;

  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? phone;
  final String promptpayId;
  final bool acceptsCash;
  final bool isOpen;
  final bool isActive;

  /// pending / approved / rejected: members apply, the admin reviews.
  final String status;
  final String? reviewNote;
  final String? category;
  final String? address;
  final double? lat;
  final double? lng;
  final String? coverUrl;
  final String? openingHours;

  /// Intro video customers can watch; null when the shop has none.
  final String? videoUrl;
  final int videoChangesPerDay;

  /// The shop said deliveries are slow (riders tied up) until this time.
  final DateTime? busyUntil;
  bool get isBusy => busyUntil != null && busyUntil!.isAfter(DateTime.now());

  /// Customers may book a time ahead, even while the shop is closed.
  final bool acceptsPreorder;

  /// How long one cooking round takes, used to tell the shop when to start a booked round.
  final int prepMinutes;

  /// Customers can open the shop: to order now, or to book ahead while it is closed.
  bool get canOrder => isOpen || acceptsPreorder;

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isApproved => status == 'approved';
  LatLng? get location => lat == null || lng == null ? null : LatLng(lat!, lng!);
}

class MenuItem {
  MenuItem.fromRow(Map<String, dynamic> r)
    : id = r['id'],
      shopId = r['shop_id'],
      name = r['name'],
      description = r['description'],
      price = _num(r['price']),
      imageUrl = r['image_url'],
      isAvailable = r['is_available'] ?? true;

  final String id;
  final String shopId;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
}

class DeliveryZone {
  DeliveryZone.fromRow(Map<String, dynamic> r) : id = r['id'], name = r['name'], fee = _num(r['fee']);

  final String id;
  final String name;
  final double fee;
}

/// A place the customer had food delivered to before, offered again at checkout.
class SavedAddress {
  SavedAddress({required this.zoneId, required this.note, this.lat, this.lng});

  final String? zoneId;
  final String note;
  final double? lat;
  final double? lng;

  LatLng? get location => lat == null || lng == null ? null : LatLng(lat!, lng!);

  /// Recent deliveries, newest first, one entry per distinct address.
  static List<SavedAddress> fromOrders(List<Map<String, dynamic>> rows, {int max = 5}) {
    final seen = <String>{};
    final out = <SavedAddress>[];
    for (final r in rows) {
      final note = ((r['address_note'] as String?) ?? '').trim();
      if (note.isEmpty) continue;
      final key = '${r['zone_id']}|${note.toLowerCase()}';
      if (!seen.add(key)) continue;
      out.add(
        SavedAddress(
          zoneId: r['zone_id'],
          note: note,
          lat: (r['dropoff_lat'] as num?)?.toDouble(),
          lng: (r['dropoff_lng'] as num?)?.toDouble(),
        ),
      );
      if (out.length == max) break;
    }
    return out;
  }
}

class Order {
  Order.fromRow(Map<String, dynamic> r)
    : id = r['id'],
      customerId = r['customer_id'],
      shopId = r['shop_id'],
      riderId = r['rider_id'],
      status = r['status'],
      fulfillment = r['fulfillment'],
      foodTotal = _num(r['food_total']),
      deliveryFee = _num(r['delivery_fee']),
      foodPaymentMethod = r['food_payment_method'],
      foodPaymentStatus = r['food_payment_status'],
      foodSlipPath = r['food_slip_path'],
      deliveryPaymentMethod = r['delivery_payment_method'],
      addressNote = r['address_note'],
      dropoffLat = (r['dropoff_lat'] as num?)?.toDouble(),
      dropoffLng = (r['dropoff_lng'] as num?)?.toDouble(),
      riderLat = (r['rider_lat'] as num?)?.toDouble(),
      riderLng = (r['rider_lng'] as num?)?.toDouble(),
      riderLocAt = r['rider_loc_at'] == null ? null : DateTime.parse(r['rider_loc_at']).toLocal(),
      createdAt = DateTime.parse(r['created_at']).toLocal(),
      scheduledFor = r['scheduled_for'] == null ? null : DateTime.parse(r['scheduled_for']).toLocal(),
      items = [
        for (final i in (r['order_items'] as List? ?? const []))
          OrderLine(i['name'], _num(i['unit_price']), i['qty'], i['note']),
      ];

  final String id;
  final String customerId;
  final String shopId;
  final String? riderId;
  final String status;
  final String fulfillment;
  final double foodTotal;
  final double deliveryFee;
  final String foodPaymentMethod;
  final String foodPaymentStatus;
  final String? foodSlipPath;
  final String deliveryPaymentMethod;
  final String? addressNote;
  final double? dropoffLat;
  final double? dropoffLng;
  final double? riderLat;
  final double? riderLng;
  final DateTime? riderLocAt;
  final DateTime createdAt;

  /// Booked time for a pre-order; null means as soon as possible.
  final DateTime? scheduledFor;
  final List<OrderLine> items;

  bool get isPreorder => scheduledFor != null;
  LatLng? get dropoff => hasDropoff ? LatLng(dropoffLat!, dropoffLng!) : null;

  bool get isDelivery => fulfillment == 'delivery';
  bool get hasDropoff => dropoffLat != null && dropoffLng != null;
  bool get hasRiderLocation => riderLat != null && riderLng != null;

  /// Rider is carrying (or about to carry) the food, so their position matters.
  bool get isOnTheWay => status == 'ready' || status == 'picked_up' || status == 'delivering';
  bool get isClosed => status == 'completed' || status == 'cancelled';
  String get shortId => id.substring(0, 6).toUpperCase();
}

class OrderLine {
  OrderLine(this.name, this.unitPrice, this.qty, this.note);
  final String name;
  final double unitPrice;
  final int qty;
  final String? note;
}

class CartLine {
  CartLine(this.item, {this.qty = 1, this.note = ''});
  final MenuItem item;
  int qty;
  String note;
}
