// Plain data classes mapped from Supabase rows.

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
      isActive = r['is_active'] ?? true;

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
      createdAt = DateTime.parse(r['created_at']).toLocal(),
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
  final DateTime createdAt;
  final List<OrderLine> items;

  bool get isDelivery => fulfillment == 'delivery';
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
