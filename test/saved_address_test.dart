import 'package:flutter_test/flutter_test.dart';
import 'package:village_food/core/models.dart';

void main() {
  test('past deliveries become a short list of distinct addresses, newest first', () {
    final list = SavedAddress.fromOrders([
      {'zone_id': 'z1', 'address_note': 'บ้านเลขที่ 12 ใกล้วัด', 'dropoff_lat': 17.7, 'dropoff_lng': 103.2},
      {'zone_id': 'z1', 'address_note': ' บ้านเลขที่ 12 ใกล้วัด ', 'dropoff_lat': null, 'dropoff_lng': null},
      {'zone_id': 'z2', 'address_note': 'ที่ทำงาน อบต.', 'dropoff_lat': null, 'dropoff_lng': null},
      {'zone_id': 'z2', 'address_note': '', 'dropoff_lat': null, 'dropoff_lng': null},
    ]);
    expect(list.map((a) => a.note), ['บ้านเลขที่ 12 ใกล้วัด', 'ที่ทำงาน อบต.']);
    expect(list.first.location?.latitude, 17.7);
    expect(list.last.location, isNull);
  });
}
