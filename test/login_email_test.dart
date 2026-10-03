import 'package:flutter_test/flutter_test.dart';
import 'package:village_food/core/api.dart';

void main() {
  const domain = Api.phoneLoginDomain;

  test('phone numbers become a digits-only login email', () {
    expect(Api.loginEmail('081-234 5678'), '0812345678@$domain');
    expect(Api.loginEmail(' 0812345678 '), '0812345678@$domain');
    expect(Api.loginEmail('021234567'), '021234567@$domain');
  });

  test('emails from older accounts pass through, lowercased', () {
    expect(Api.loginEmail(' Me@Example.com '), 'me@example.com');
  });

  test('anything else is rejected', () {
    expect(() => Api.loginEmail('1234'), throwsFormatException);
    expect(() => Api.loginEmail('08123456789'), throwsFormatException);
    expect(() => Api.loginEmail(''), throwsFormatException);
  });
}
