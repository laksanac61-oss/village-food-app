// Pre-order planning: travel time estimates from map pins and grouping booked orders into delivery rounds.
// Distances are straight-line between pins, stretched by a road factor, at motorbike speed in a village.

import 'dart:math';

import 'package:latlong2/latlong.dart';

import 'labels.dart';
import 'models.dart';

/// Customers whose times are this close may be asked to share one delivery round.
const roundWindow = Duration(minutes: 30);

/// Customers this close to each other (km) count as neighbours for one round.
const neighbourKm = 1.0;

/// Earliest booking from now, matching the database rule.
const minBookAhead = Duration(minutes: 30);

const _roadFactor = 1.3;
const _speedKmh = 25.0;
const _handoverMinutes = 3;

/// Used when a pin is missing, so the shop still gets a start time.
const unknownTravelMinutes = 10;

double distanceKm(LatLng a, LatLng b) => const Distance().as(LengthUnit.Meter, a, b) / 1000;

/// Minutes to ride [km] of straight-line distance and hand the food over.
int travelMinutes(double km) => (km * _roadFactor / _speedKmh * 60).ceil() + _handoverMinutes;

/// Minutes from the shop to [to], or a default when either pin is missing.
int legMinutes(LatLng? from, LatLng? to) =>
    from == null || to == null ? unknownTravelMinutes : travelMinutes(distanceKm(from, to));

/// "วันนี้ 12:30", "พรุ่งนี้ 08:00" or "5/10 18:00".
String slotLabel(DateTime t, {DateTime? now}) {
  now ??= DateTime.now();
  final day = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = day.difference(today).inDays;
  final d = switch (diff) {
    0 => 'วันนี้',
    1 => 'พรุ่งนี้',
    _ => '${t.day}/${t.month}',
  };
  return '$d ${hhmm(t)}';
}

/// One trip out of the shop: booked orders for nearby homes at about the same time.
class DeliveryRound {
  DeliveryRound(this.time, this.stops, this.legs, this.prepMinutes);

  /// The booked time; the first stop arrives then.
  final DateTime time;

  /// Orders in riding order (nearest first).
  final List<Order> stops;

  /// Minutes for each leg: shop to stop 1, stop 1 to stop 2, ...
  final List<int> legs;
  final int prepMinutes;

  bool get isPickup => stops.first.fulfillment == 'pickup';
  DateTime get leaveShop => isPickup ? time : time.subtract(Duration(minutes: legs.first));
  DateTime get startCooking => leaveShop.subtract(Duration(minutes: prepMinutes));

  /// Estimated arrival at each stop.
  List<DateTime> get arrivals {
    var t = leaveShop;
    return [for (final m in legs) t = t.add(Duration(minutes: m))];
  }

  /// Total of each dish across the round, for preparing ingredients.
  Map<String, int> get dishes => dishTotals(stops);
}

Map<String, int> dishTotals(Iterable<Order> orders) {
  final out = <String, int>{};
  for (final o in orders) {
    for (final l in o.items) {
      out.update(l.name, (q) => q + l.qty, ifAbsent: () => l.qty);
    }
  }
  return out;
}

/// Groups booked, still-open orders into delivery rounds, earliest first.
/// A delivery order joins a round when it is booked for the same time and its pin is within [neighbourKm]
/// of a home already in the round. Customers agree to a shared time at checkout (within [roundWindow]),
/// so nobody's food arrives earlier or later than they chose. Pickups and orders without a pin stand alone.
List<DeliveryRound> planRounds(List<Order> orders, {LatLng? shop, int prepMinutes = 20}) {
  final booked = orders.where((o) => o.isPreorder && !o.isClosed).toList()
    ..sort((a, b) => a.scheduledFor!.compareTo(b.scheduledFor!));
  final groups = <List<Order>>[];
  for (final o in booked) {
    final pin = o.dropoff;
    final group = !o.isDelivery || pin == null
        ? null
        : groups.where((g) {
            final first = g.first;
            return first.isDelivery &&
                first.dropoff != null &&
                o.scheduledFor == first.scheduledFor &&
                g.any((x) => distanceKm(x.dropoff!, pin) <= neighbourKm);
          }).firstOrNull;
    if (group == null) {
      groups.add([o]);
    } else {
      group.add(o);
    }
  }
  return [
    for (final g in groups)
      if (!g.first.isDelivery)
        DeliveryRound(g.first.scheduledFor!, g, const [0], prepMinutes)
      else
        _route(g, shop, prepMinutes),
  ];
}

/// Nearest-next riding order from the shop.
DeliveryRound _route(List<Order> group, LatLng? shop, int prepMinutes) {
  final left = [...group];
  final stops = <Order>[];
  final legs = <int>[];
  LatLng? at = shop;
  while (left.isNotEmpty) {
    final here = at;
    final next = here == null
        ? left.first
        : left.reduce(
            (a, b) => distanceKm(here, a.dropoff ?? here) <= distanceKm(here, b.dropoff ?? here) ? a : b,
          );
    legs.add(legMinutes(at, next.dropoff));
    stops.add(next);
    left.remove(next);
    at = next.dropoff ?? at;
  }
  final time = group.map((o) => o.scheduledFor!).reduce((a, b) => a.isBefore(b) ? a : b);
  return DeliveryRound(time, stops, legs, max(prepMinutes, 0));
}
