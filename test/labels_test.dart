import 'package:flutter_test/flutter_test.dart';
import 'package:village_food/core/labels.dart';

void main() {
  test('phone numbers are shown with dashes', () {
    expect(phoneLabel('0833474363'), '083-347-4363');
    expect(phoneLabel('021234567'), '021234567');
  });

  test('every role has a Thai label', () {
    expect(roleLabel.keys, containsAll(['customer', 'shop_owner', 'rider', 'admin']));
  });
}
