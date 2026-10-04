import 'models.dart';

/// Something the shop should notice: a new order, or a customer's payment slip waiting to be checked.
class OrderEvent {
  OrderEvent(this.order, {required this.isSlip});
  final Order order;
  final bool isSlip;
}

/// Compares each snapshot of the shop's orders with the previous one. The first snapshot is what was
/// already there when the screen opened, so it raises nothing.
class OrderWatcher {
  Map<String, String>? _payment; // order id -> food payment status

  List<OrderEvent> update(List<Map<String, dynamic>> rows) {
    final orders = rows.map(Order.fromRow).toList();
    final before = _payment;
    _payment = {for (final o in orders) o.id: o.foodPaymentStatus};
    if (before == null) return const [];
    return [
      for (final o in orders)
        if (!before.containsKey(o.id) && o.status == 'pending')
          OrderEvent(o, isSlip: false)
        else if (before.containsKey(o.id) &&
            before[o.id] != 'slip_uploaded' &&
            o.foodPaymentStatus == 'slip_uploaded' &&
            !o.isClosed)
          OrderEvent(o, isSlip: true),
    ];
  }
}
