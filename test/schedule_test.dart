import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:village_food/core/models.dart';
import 'package:village_food/core/schedule.dart';

Order _order(
  String id,
  DateTime? at, {
  double? lat,
  double? lng,
  String fulfillment = 'delivery',
  String status = 'accepted',
  List<Map<String, dynamic>> items = const [],
}) => Order.fromRow({
  'id': '${id}0000000000',
  'customer_id': 'c',
  'shop_id': 's',
  'status': status,
  'fulfillment': fulfillment,
  'food_total': 0,
  'delivery_fee': 0,
  'food_payment_method': 'cash',
  'food_payment_status': 'unpaid',
  'delivery_payment_method': 'cash',
  'dropoff_lat': lat,
  'dropoff_lng': lng,
  'created_at': DateTime(2026, 10, 4, 9).toIso8601String(),
  'scheduled_for': at?.toIso8601String(),
  'order_items': items,
});

void main() {
  const shop = LatLng(13.7500, 100.5000);
  final noon = DateTime(2026, 10, 4, 12);

  test('travel time grows with distance and has a floor for handover', () {
    expect(travelMinutes(0), 3);
    expect(travelMinutes(1), 7); // 1.3 km of road at 25 km/h is about 3.1 minutes, plus 3
    expect(travelMinutes(3), greaterThan(travelMinutes(1)));
    expect(legMinutes(null, shop), unknownTravelMinutes);
  });

  test('neighbours booked for the same time share one round in riding order', () {
    final far = _order('a', noon, lat: 13.7560, lng: 100.5000); // about 670 m from the shop
    final near = _order('b', noon, lat: 13.7520, lng: 100.5000); // about 220 m
    final rounds = planRounds([far, near], shop: shop, prepMinutes: 20);
    expect(rounds, hasLength(1));
    final r = rounds.single;
    expect(r.stops.map((o) => o.id), [near.id, far.id]);
    expect(r.leaveShop, noon.subtract(Duration(minutes: r.legs.first)));
    expect(r.startCooking, r.leaveShop.subtract(const Duration(minutes: 20)));
    expect(r.arrivals.first, noon);
    expect(r.arrivals.last.isAfter(noon), isTrue);
  });

  test('different times, far homes, pickups and closed orders are kept apart', () {
    final rounds = planRounds([
      _order('a', noon, lat: 13.7520, lng: 100.5000),
      _order('b', noon.add(const Duration(minutes: 20)), lat: 13.7521, lng: 100.5000), // kept own time
      _order('c', noon, lat: 13.8000, lng: 100.5000), // about 5.5 km away
      _order('d', noon, fulfillment: 'pickup'),
      _order('e', noon, lat: 13.7520, lng: 100.5000, status: 'cancelled'),
      _order('f', null, lat: 13.7520, lng: 100.5000), // order-now, not a booking
    ], shop: shop);
    expect(rounds, hasLength(4));
    expect(rounds.where((r) => r.isPickup).single.leaveShop, noon);
    expect(rounds.last.time, noon.add(const Duration(minutes: 20)));
  });

  test('dish totals add up across a round', () {
    final rounds = planRounds([
      _order(
        'a',
        noon,
        lat: 13.752,
        lng: 100.5,
        items: [
          {'name': 'ข้าวมันไก่', 'unit_price': 50, 'qty': 2},
        ],
      ),
      _order(
        'b',
        noon,
        lat: 13.7521,
        lng: 100.5,
        items: [
          {'name': 'ข้าวมันไก่', 'unit_price': 50, 'qty': 1},
          {'name': 'น้ำซุป', 'unit_price': 10, 'qty': 1},
        ],
      ),
    ], shop: shop);
    expect(rounds.single.dishes, {'ข้าวมันไก่': 3, 'น้ำซุป': 1});
  });

  test('slot labels say today and tomorrow in Thai', () {
    final now = DateTime(2026, 10, 4, 9);
    expect(slotLabel(DateTime(2026, 10, 4, 12, 30), now: now), 'วันนี้ 12:30');
    expect(slotLabel(DateTime(2026, 10, 5, 8), now: now), 'พรุ่งนี้ 08:00');
    expect(slotLabel(DateTime(2026, 10, 6, 18), now: now), '6/10 18:00');
  });
}
