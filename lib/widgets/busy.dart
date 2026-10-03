import 'package:flutter/material.dart';

import '../core/labels.dart';
import '../core/models.dart';

const busyColor = Colors.orange;

/// Small orange "busy" tag shown next to a shop's name.
class BusyTag extends StatelessWidget {
  const BusyTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: busyColor, borderRadius: BorderRadius.circular(8)),
    child: const Text(
      'busy',
      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}

/// Orange notice explaining that delivery is slow right now.
class BusyNotice extends StatelessWidget {
  const BusyNotice({super.key, this.shop, this.noRiders = false});
  final Shop? shop;
  final bool noRiders;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.orange.shade50,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: busyColor),
    ),
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top, color: busyColor),
          const SizedBox(width: 8),
          Expanded(child: Text(busyMessage(shop, noRiders: noRiders))),
        ],
      ),
    ),
  );
}

String busyMessage(Shop? shop, {bool noRiders = false}) {
  if (shop != null && shop.isBusy) {
    return 'ร้านแจ้งว่าไรเดอร์ติดงาน การส่งอาจล่าช้า (ถึงประมาณ ${hhmm(shop.busyUntil!)})';
  }
  if (noRiders) return 'ตอนนี้ยังไม่มีไรเดอร์ออนไลน์ การส่งอาจล่าช้า';
  return '';
}
