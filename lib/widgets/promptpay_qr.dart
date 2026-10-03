import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/labels.dart';
import '../core/promptpay.dart';

/// QR the customer scans with any Thai banking app; amount is pre-filled.
class PromptPayQr extends StatelessWidget {
  const PromptPayQr({super.key, required this.target, required this.amount, required this.payee});

  final String target;
  final double amount;
  final String payee;

  @override
  Widget build(BuildContext context) {
    String? payload;
    try {
      payload = promptPayPayload(target, amount: amount);
    } on ArgumentError {
      payload = null;
    }
    return Column(
      children: [
        Text('สแกนจ่ายให้ $payee', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (payload == null)
          const Text('เลขพร้อมเพย์ของผู้รับไม่ถูกต้อง')
        else
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: QrImageView(data: payload, size: 220),
          ),
        const SizedBox(height: 4),
        Text('ยอด ${baht(amount)} · พร้อมเพย์ $target'),
      ],
    );
  }
}
