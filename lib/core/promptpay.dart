/// Builds Thai PromptPay QR payloads (EMVCo merchant-presented format).
///
/// The payload is a plain string; render it with any QR widget. Any Thai
/// banking app can scan it and will pre-fill the receiver and the amount.
library;

const _aid = 'A000000677010111';

String _field(String id, String value) => '$id${value.length.toString().padLeft(2, '0')}$value';

/// [target] is a mobile number (e.g. 0812345678), a 13-digit citizen/tax ID,
/// or a 15-digit e-wallet ID. Dashes and spaces are ignored.
/// Pass [amount] to make a one-time QR with the amount filled in.
String promptPayPayload(String target, {double? amount}) {
  final id = target.replaceAll(RegExp(r'[^0-9]'), '');
  final String account;
  if (id.length >= 15) {
    account = _field('03', id);
  } else if (id.length >= 13) {
    account = _field('02', id);
  } else if (id.length == 10 && id.startsWith('0')) {
    account = _field('01', '0066${id.substring(1)}');
  } else {
    throw ArgumentError.value(target, 'target', 'not a PromptPay mobile number or ID');
  }
  if (amount != null && (amount <= 0 || amount.isNaN)) {
    throw ArgumentError.value(amount, 'amount', 'must be positive');
  }

  final buf = StringBuffer()
    ..write(_field('00', '01'))
    ..write(_field('01', amount == null ? '11' : '12'))
    ..write(_field('29', _field('00', _aid) + account))
    ..write(_field('58', 'TH'))
    ..write(_field('53', '764'));
  if (amount != null) buf.write(_field('54', amount.toStringAsFixed(2)));
  buf.write('6304');
  final body = buf.toString();
  return body + crc16(body).toRadixString(16).toUpperCase().padLeft(4, '0');
}

/// CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF), as EMVCo requires.
int crc16(String data) {
  var crc = 0xFFFF;
  for (final byte in data.codeUnits) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xFFFF;
    }
  }
  return crc;
}
