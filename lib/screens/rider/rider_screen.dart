import 'dart:typed_data';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/labels.dart';
import '../../core/location.dart';
import '../../core/models.dart';
import '../../core/promptpay.dart';
import '../../widgets/common.dart';
import '../../widgets/order_card.dart';

class RiderScreen extends StatelessWidget {
  const RiderScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ไรเดอร์')),
    body: Loader<Map<String, dynamic>?>(
      load: Api.myRider,
      builder: (context, rider, reload) => switch (rider?['status']) {
        null => _RegisterForm(onDone: reload),
        'pending_approval' => const Empty('ส่งใบสมัครแล้ว รอผู้ดูแลระบบอนุมัติ'),
        'suspended' => const Empty('บัญชีไรเดอร์ถูกระงับ ติดต่อผู้ดูแลระบบ'),
        _ => _RiderJobs(online: rider!['is_online'] == true, onToggle: reload),
      },
    ),
  );
}

class _RiderJobs extends StatelessWidget {
  const _RiderJobs({required this.online, required this.onToggle});
  final bool online;
  final VoidCallback onToggle;

  Future<(List<Order>, List<Order>)> _load() async => (await Api.openJobs(), await Api.myDeliveries());

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SwitchListTile(
        title: Text(online ? 'ออนไลน์ · กำลังรับงาน' : 'ออฟไลน์'),
        value: online,
        onChanged: (v) async {
          if (await guard(context, () => Api.setOnline(v))) onToggle();
        },
      ),
      const Divider(height: 1),
      Expanded(
        child: Loader<(List<Order>, List<Order>)>(
          load: _load,
          reloadOn: Api.orderChanges(),
          builder: (context, data, reload) {
            final (jobs, mine) = data;
            final active = mine.where((o) => !o.isClosed).toList();
            final done = mine.where((o) => o.isClosed).toList();
            final today = DateTime.now();
            final earnedToday = done
                .where(
                  (o) =>
                      o.status == 'completed' &&
                      o.createdAt.year == today.year &&
                      o.createdAt.month == today.month &&
                      o.createdAt.day == today.day,
                )
                .fold<double>(0, (s, o) => s + o.deliveryFee);
            return ListView(
              children: [
                ListTile(title: Text('ค่าส่งวันนี้ ${baht(earnedToday)}')),
                _LocationSharer(orders: active.where((o) => o.isOnTheWay).toList()),
                if (active.isNotEmpty) const _H('งานของฉัน'),
                for (final o in active)
                  OrderCard(
                    order: o,
                    actions: [
                      if (o.status == 'ready') _step(context, reload, o, 'รับอาหารแล้ว', 'picked_up'),
                      if (o.status == 'picked_up') _step(context, reload, o, 'กำลังไปส่ง', 'delivering'),
                      if (o.status == 'delivering') _step(context, reload, o, 'ส่งสำเร็จ', 'completed'),
                      if (o.status == 'accepted' || o.status == 'cooking')
                        const Chip(label: Text('รอร้านทำอาหาร')),
                      if (o.hasDropoff)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.navigation),
                          label: const Text('นำทางไปบ้านลูกค้า'),
                          onPressed: () => launchUrl(directionsUrl(o.dropoffLat!, o.dropoffLng!)),
                        ),
                    ],
                  ),
                if (online) ...[
                  const _H('งานใหม่'),
                  if (jobs.isEmpty) const ListTile(title: Text('ยังไม่มีงานใหม่')),
                  for (final o in jobs)
                    OrderCard(
                      order: o,
                      actions: [
                        FilledButton(
                          onPressed: () async {
                            late bool got;
                            if (await guard(context, () async => got = await Api.claim(o.id))) {
                              if (!got && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('มีไรเดอร์คนอื่นรับงานนี้ไปแล้ว')),
                                );
                              }
                              reload();
                            }
                          },
                          child: Text('รับงาน · ค่าส่ง ${baht(o.deliveryFee)}'),
                        ),
                      ],
                    ),
                ],
                if (done.isNotEmpty) const _H('ประวัติ'),
                for (final o in done.take(20)) OrderCard(order: o),
              ],
            );
          },
        ),
      ),
    ],
  );

  Widget _step(BuildContext context, VoidCallback reload, Order o, String label, String status) =>
      FilledButton(
        onPressed: () async {
          if (await guard(context, () => Api.setStatus(o.id, status))) reload();
        },
        child: Text(label),
      );
}

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _promptpay = TextEditingController();
  final _vehicle = TextEditingController(text: 'มอเตอร์ไซค์');
  final _plate = TextEditingController();
  Uint8List? _idCard;
  Uint8List? _photo;
  bool _busy = false;

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      promptPayPayload(_promptpay.text);
    } on ArgumentError {
      messenger.showSnackBar(const SnackBar(content: Text('เลขพร้อมเพย์ไม่ถูกต้อง')));
      return;
    }
    if (_idCard == null || _photo == null || _plate.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('กรุณากรอกข้อมูลและแนบรูปให้ครบ')));
      return;
    }
    setState(() => _busy = true);
    final ok = await guard(
      context,
      () => Api.registerRider(
        promptpayId: _promptpay.text.trim(),
        vehicleType: _vehicle.text.trim(),
        plateNo: _plate.text.trim(),
        idCard: _idCard!,
        photo: _photo!,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onDone();
  }

  Widget _pick(String label, Uint8List? bytes, void Function(Uint8List) set) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: bytes == null ? const Icon(Icons.add_a_photo) : Image.memory(bytes, width: 48),
    title: Text(label),
    trailing: Icon(bytes == null ? Icons.chevron_right : Icons.check, color: Colors.green),
    onTap: () async {
      final b = await pickPhoto();
      if (b != null) setState(() => set(b));
    },
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('สมัครเป็นไรเดอร์', style: Theme.of(context).textTheme.titleLarge),
      const Text('รับงานส่งอาหารจากร้านในหมู่บ้านไปให้ลูกค้า ได้ค่าส่งเต็มจำนวน'),
      TextField(
        controller: _promptpay,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'พร้อมเพย์สำหรับรับค่าส่ง'),
      ),
      TextField(
        controller: _vehicle,
        decoration: const InputDecoration(labelText: 'ประเภทรถ'),
      ),
      TextField(
        controller: _plate,
        decoration: const InputDecoration(labelText: 'ทะเบียนรถ'),
      ),
      const SizedBox(height: 8),
      _pick('รูปบัตรประชาชน', _idCard, (b) => _idCard = b),
      _pick('รูปถ่ายหน้าตรง', _photo, (b) => _photo = b),
      const SizedBox(height: 16),
      FilledButton(onPressed: _busy ? null : _submit, child: const Text('ส่งใบสมัคร')),
    ],
  );
}

/// While the rider has food to deliver, sends their GPS position every 15 seconds
/// so the customer's map can follow them. Works only while this screen stays open.
class _LocationSharer extends StatefulWidget {
  const _LocationSharer({required this.orders});
  final List<Order> orders;

  @override
  State<_LocationSharer> createState() => _LocationSharerState();
}

class _LocationSharerState extends State<_LocationSharer> {
  Timer? _timer;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _send());
    _send();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    if (widget.orders.isEmpty) return;
    final here = await currentLocation();
    if (!mounted) return;
    if (here == null) {
      if (!_failed) setState(() => _failed = true);
      return;
    }
    if (_failed) setState(() => _failed = false);
    for (final o in widget.orders) {
      // A failed update (e.g. order just completed) is fine to skip; the next tick retries.
      await Api.updateRiderLocation(o.id, here.latitude, here.longitude).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orders.isEmpty) return const SizedBox.shrink();
    return ListTile(
      leading: Icon(
        _failed ? Icons.location_off : Icons.my_location,
        color: _failed ? Colors.red : Colors.green,
      ),
      title: Text(
        _failed ? 'เปิดตำแหน่ง (GPS) ไม่ได้ ลูกค้าจะไม่เห็นคุณบนแผนที่' : 'กำลังแชร์ตำแหน่งให้ลูกค้า',
      ),
      subtitle: const Text('เปิดหน้านี้ค้างไว้ระหว่างไปส่ง'),
    );
  }
}
