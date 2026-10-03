import 'package:flutter_test/flutter_test.dart';
import 'package:village_food/core/promptpay.dart';

// Expected payloads cross-checked against the promptpay-qr npm package.
void main() {
  test('crc16 matches CCITT-FALSE check value', () {
    expect(crc16('123456789'), 0x29B1);
  });

  test('mobile number without amount', () {
    expect(
      promptPayPayload('081-234-5678'),
      '00020101021129370016A000000677010111011300668123456785802TH530376463045D82',
    );
  });

  test('mobile number with amount', () {
    expect(
      promptPayPayload('0812345678', amount: 110),
      '00020101021229370016A000000677010111011300668123456785802TH53037645406110.00630450A9',
    );
  });

  test('citizen ID with amount', () {
    expect(
      promptPayPayload('1234567890123', amount: 55.5),
      '00020101021229370016A000000677010111021312345678901235802TH5303764540555.506304B693',
    );
  });

  test('rejects bad input', () {
    expect(() => promptPayPayload('12345'), throwsArgumentError);
    expect(() => promptPayPayload('0812345678', amount: 0), throwsArgumentError);
  });
}
