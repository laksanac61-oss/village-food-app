import 'package:flutter_test/flutter_test.dart';
import 'package:village_food/core/order_watch.dart';

Map<String, dynamic> _row(String id, {String status = 'pending', String pay = 'unpaid'}) => {
  'id': '${id}000000000',
  'customer_id': 'c',
  'shop_id': 's',
  'status': status,
  'fulfillment': 'delivery',
  'food_total': 0,
  'delivery_fee': 15,
  'food_payment_method': 'promptpay',
  'food_payment_status': pay,
  'delivery_payment_method': 'cash',
  'created_at': '2026-10-04T10:00:00Z',
};

void main() {
  test('orders already there when the screen opens raise nothing', () {
    final w = OrderWatcher();
    expect(w.update([_row('a'), _row('b')]), isEmpty);
  });

  test('a new pending order raises one alert, and only once', () {
    final w = OrderWatcher()..update([_row('a')]);
    final events = w.update([_row('a'), _row('b')]);
    expect(events.single.order.id, startsWith('b'));
    expect(events.single.isSlip, isFalse);
    expect(w.update([_row('a'), _row('b')]), isEmpty);
  });

  test('a slip sent for an existing order raises a slip alert', () {
    final w = OrderWatcher()..update([_row('a')]);
    final events = w.update([_row('a', pay: 'slip_uploaded')]);
    expect(events.single.isSlip, isTrue);
    expect(w.update([_row('a', pay: 'slip_uploaded', status: 'accepted')]), isEmpty);
  });

  test('status changes made by the shop itself stay quiet', () {
    final w = OrderWatcher()..update([_row('a')]);
    expect(w.update([_row('a', status: 'accepted')]), isEmpty);
    expect(w.update([_row('a', status: 'cancelled', pay: 'slip_uploaded')]), isEmpty);
  });
}
