import 'package:flutter_test/flutter_test.dart';
import 'package:village_food/core/models.dart';
import 'package:village_food/widgets/busy.dart';

Shop _shop(DateTime? busyUntil) => Shop.fromRow({
  'id': 's',
  'owner_id': 'o',
  'name': 'ร้าน',
  'promptpay_id': '0812345678',
  'busy_until': busyUntil?.toUtc().toIso8601String(),
});

void main() {
  test('a shop is busy only until the time it set', () {
    expect(_shop(null).isBusy, isFalse);
    expect(_shop(DateTime.now().add(const Duration(minutes: 30))).isBusy, isTrue);
    expect(_shop(DateTime.now().subtract(const Duration(minutes: 1))).isBusy, isFalse);
  });

  test('the warning says why delivery is slow', () {
    final busy = _shop(DateTime.now().add(const Duration(minutes: 30)));
    expect(busyMessage(busy), contains('ไรเดอร์ติดงาน'));
    expect(busyMessage(_shop(null), noRiders: true), contains('ไม่มีไรเดอร์ออนไลน์'));
  });
}
