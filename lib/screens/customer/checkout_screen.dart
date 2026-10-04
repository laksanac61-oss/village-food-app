import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../core/schedule.dart';
import '../../widgets/busy.dart';
import '../../widgets/common.dart';
import '../../widgets/maps.dart';
import 'order_detail_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.shop, required this.cart});
  final Shop shop;
  final List<CartLine> cart;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _fulfillment = 'delivery';
  String _foodPayment = 'promptpay';
  String _deliveryPayment = 'cash';
  DeliveryZone? _zone;
  final _address = TextEditingController();
  LatLng? _home;
  bool _busy = false;
  late final Future<List<DeliveryZone>> _zones = Api.zones();
  List<SavedAddress> _saved = [];
  SavedAddress? _picked;
  late Shop _shop = widget.shop;
  bool _noRiders = false;

  /// Booked time; null orders for as soon as possible. A closed shop only takes bookings.
  late DateTime? _when = widget.shop.isOpen ? null : _defaultSlot();

  @override
  void initState() {
    super.initState();
    _prefill();
    _checkDelivery();
  }

  /// Fresh busy flag and rider count: the shop list may have been loaded a while ago.
  Future<void> _checkDelivery() async {
    try {
      final (shop, online) = (await Api.shop(widget.shop.id), await Api.ridersOnline());
      if (!mounted) return;
      setState(() {
        _shop = shop;
        _noRiders = online == 0;
      });
    } catch (_) {} // the warning is a courtesy; ordering still works without it
  }

  bool get _deliverySlow => _shop.isBusy || _noRiders;

  /// When delivery is slow, the customer chooses to wait, collect the food themselves, or not order.
  /// Returns true to go ahead with the order as it is.
  Future<bool> _confirmSlowDelivery() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.hourglass_top, color: busyColor, size: 40),
        title: const Text('ตอนนี้ส่งช้ากว่าปกติ'),
        content: Text(busyMessage(_shop, noRiders: _noRiders)),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx, 'wait'), child: const Text('รอได้ สั่งเลย')),
          OutlinedButton(onPressed: () => Navigator.pop(ctx, 'pickup'), child: const Text('ไปรับเองที่ร้าน')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('ยกเลิก')),
        ],
      ),
    );
    if (!mounted) return false;
    switch (choice) {
      case 'wait':
        return true;
      case 'pickup':
        setState(() => _fulfillment = 'pickup');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เปลี่ยนเป็นไปรับเองที่ร้านแล้ว ตรวจยอดแล้วกด "สั่งอาหาร" อีกครั้ง')),
        );
      case 'cancel':
        Navigator.pop(context);
    }
    return false;
  }

  /// Fills in the last delivery address so a returning customer can order straight away;
  /// a first-time customer gets the address from their profile.
  Future<void> _prefill() async {
    final saved = await Api.mySavedAddresses().catchError((_) => <SavedAddress>[]);
    if (!mounted) return;
    setState(() => _saved = saved);
    if (saved.isNotEmpty) return _use(saved.first);
    final p = await Api.myProfile();
    if (p == null || !mounted || _address.text.isNotEmpty) return;
    _address.text = [p['house_no'], p['soi']].where((s) => (s ?? '').isNotEmpty).join(' ');
    if (p['home_lat'] != null && p['home_lng'] != null) {
      setState(() => _home = LatLng((p['home_lat'] as num).toDouble(), (p['home_lng'] as num).toDouble()));
    }
  }

  Future<void> _use(SavedAddress a) async {
    final zones = await _zones;
    if (!mounted) return;
    setState(() {
      _picked = a;
      _address.text = a.note;
      _home = a.location ?? _home;
      // the zone may have been removed since; then the customer picks one again
      _zone = zones.where((z) => z.id == a.zoneId).firstOrNull;
    });
  }

  Future<void> _pickHome() async {
    final p = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => PinPickerScreen(initial: _home)),
    );
    if (p == null) return;
    setState(() => _home = p);
    Api.saveHomePin(p.latitude, p.longitude).ignore(); // remembered for next time
  }

  static DateTime _defaultSlot() {
    // next quarter hour at least 45 minutes away, so there is time to fill in the form
    final t = DateTime.now().add(const Duration(minutes: 45));
    final up = (15 - t.minute % 15) % 15;
    return DateTime(t.year, t.month, t.day, t.hour, t.minute + up);
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final start = _when ?? _defaultSlot();
    final day = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 2)),
      helpText: 'จองวันไหน',
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
      helpText: 'รับอาหารกี่โมง',
    );
    if (time == null || !mounted) return;
    final picked = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (picked.isBefore(DateTime.now().add(minBookAhead))) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('จองล่วงหน้าอย่างน้อย 30 นาทีนะคะ')));
      return;
    }
    setState(() => _when = picked);
  }

  /// A neighbour already booked a time within 30 minutes: ask whether to share that round.
  /// Returns false when the customer backs out.
  Future<bool> _offerNeighbourRound() async {
    final near = await Api.nearbyPreorder(widget.shop.id, _when!, _home!).catchError((_) => null);
    if (near == null || !mounted || near.slot.isBefore(DateTime.now().add(minBookAhead))) return true;
    final gap = near.slot.difference(_when!).inMinutes.abs();
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.groups, size: 40),
        title: const Text('มีบ้านใกล้คุณจองเวลาใกล้กัน'),
        content: Text(
          'ร้านมีออเดอร์ไปส่งบ้านใกล้คุณ (ไม่เกิน 1 กม.) เวลา ${slotLabel(near.slot)} น. อยู่แล้ว '
          'ห่างจากเวลาที่คุณเลือก $gap นาที\n\n'
          'รับอาหารเวลา ${hhmm(near.slot)} น. พร้อมรอบนั้นได้ไหมคะ ร้านจะทำและส่งรอบเดียวกัน',
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'join'),
            child: Text('ได้ รับเวลา ${hhmm(near.slot)} น.'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: Text('ขอเวลาเดิม ${hhmm(_when!)} น.'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
        ],
      ),
    );
    if (!mounted || choice == null) return false;
    if (choice == 'join') setState(() => _when = near.slot);
    return true;
  }

  /// "About N minutes" from the shop pin to the home pin, when both are known.
  String? get _travelNote {
    final shop = _shop.location;
    if (_fulfillment != 'delivery' || shop == null || _home == null) return null;
    final km = distanceKm(shop, _home!);
    return 'บ้านห่างจากร้านประมาณ ${km.toStringAsFixed(1)} กม. ไรเดอร์ใช้เวลาราว ${travelMinutes(km)} นาที';
  }

  double get _food => widget.cart.fold(0, (s, l) => s + l.item.price * l.qty);

  Future<void> _place() async {
    if (_fulfillment == 'delivery' && (_zone == null || _address.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาเลือกโซนและใส่ที่อยู่สำหรับจัดส่ง')));
      return;
    }
    if (_when == null && _fulfillment == 'delivery' && _deliverySlow && !await _confirmSlowDelivery()) return;
    if (!mounted) return;
    if (_when != null && DateTime.now().add(minBookAhead).isAfter(_when!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เวลาจองต้องห่างจากตอนนี้อย่างน้อย 30 นาที กรุณาเลือกเวลาใหม่')),
      );
      return;
    }
    if (_when != null && _fulfillment == 'delivery' && _home != null && !await _offerNeighbourRound()) return;
    if (!mounted) return;
    setState(() => _busy = true);
    late String id;
    final ok = await guard(context, () async {
      id = await Api.placeOrder(
        shopId: widget.shop.id,
        cart: widget.cart,
        fulfillment: _fulfillment,
        zoneId: _zone?.id,
        foodPayment: _foodPayment,
        deliveryPayment: _deliveryPayment,
        addressNote: _address.text.trim(),
        scheduledFor: _when,
      );
      if (_fulfillment == 'delivery' && _home != null) {
        await Api.setDropoff(id, _home!.latitude, _home!.longitude);
      }
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)),
        result: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fee = _fulfillment == 'delivery' ? (_zone?.fee ?? 0) : 0.0;
    return Scaffold(
      appBar: AppBar(title: const Text('ยืนยันการสั่ง')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.shop.name, style: Theme.of(context).textTheme.titleLarge),
          for (final l in widget.cart)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${l.qty} × ${l.item.name}'),
              subtitle: TextField(
                decoration: const InputDecoration(hintText: 'หมายเหตุ เช่น ไม่ใส่ผัก', isDense: true),
                onChanged: (v) => l.note = v,
              ),
              trailing: Text(baht(l.item.price * l.qty)),
            ),
          const Divider(),
          const Text('สั่งตอนนี้ หรือจองเวลาล่วงหน้า'),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: const Text('สั่งเลย'),
                icon: const Icon(Icons.flash_on),
                enabled: _shop.isOpen,
              ),
              ButtonSegment(
                value: true,
                label: const Text('จองล่วงหน้า'),
                icon: const Icon(Icons.schedule),
                enabled: _shop.acceptsPreorder,
              ),
            ],
            selected: {_when != null},
            onSelectionChanged: (s) => setState(() => _when = s.first ? (_when ?? _defaultSlot()) : null),
          ),
          if (!_shop.isOpen)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('ร้านปิดอยู่ตอนนี้ จองล่วงหน้าได้', style: TextStyle(color: Colors.grey)),
            ),
          if (_when != null)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.event_available),
                title: Text('รับอาหาร ${slotLabel(_when!)} น.'),
                subtitle: const Text('ร้านจะเตรียมวัตถุดิบและเริ่มทำให้ทันเวลา'),
                trailing: TextButton(onPressed: _pickTime, child: const Text('เปลี่ยนเวลา')),
                onTap: _pickTime,
              ),
            ),
          const SizedBox(height: 12),
          const Text('รับอาหารแบบไหน'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'delivery',
                label: Text('ให้ไรเดอร์ส่ง'),
                icon: Icon(Icons.delivery_dining),
              ),
              ButtonSegment(value: 'pickup', label: Text('รับเองที่ร้าน'), icon: Icon(Icons.store)),
            ],
            selected: {_fulfillment},
            onSelectionChanged: (s) => setState(() => _fulfillment = s.first),
          ),
          if (_fulfillment == 'delivery') ...[
            if (_deliverySlow && _when == null) BusyNotice(shop: _shop, noRiders: _noRiders),
            if (_saved.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('ส่งที่เดิม แตะเพื่อเลือก'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final a in _saved)
                    ChoiceChip(
                      avatar: const Icon(Icons.history, size: 18),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(a.note, overflow: TextOverflow.ellipsis),
                      ),
                      selected: identical(_picked, a),
                      onSelected: (_) => _use(a),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            FutureBuilder<List<DeliveryZone>>(
              future: _zones,
              builder: (context, snap) => DropdownButtonFormField<DeliveryZone>(
                // re-created when a saved address picks the zone
                key: ValueKey(_zone?.id),
                initialValue: _zone,
                decoration: const InputDecoration(labelText: 'โซนจัดส่ง'),
                items: [
                  for (final z in snap.data ?? <DeliveryZone>[])
                    DropdownMenuItem(value: z, child: Text('${z.name} (ค่าส่ง ${baht(z.fee)})')),
                ],
                onChanged: (z) => setState(() => _zone = z),
              ),
            ),
            TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'บ้านเลขที่ / ซอย / จุดสังเกต'),
              onChanged: (_) {
                if (_picked != null) setState(() => _picked = null);
              },
            ),
            const SizedBox(height: 8),
            if (_home != null) OrderMap(dropoff: _home, height: 160),
            if (_travelNote != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_travelNote!, style: const TextStyle(color: Colors.grey)),
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.location_on),
              label: Text(
                _home == null ? 'ปักหมุดบ้านบนแผนที่ (ช่วยให้ไรเดอร์หาบ้านเจอ)' : 'เปลี่ยนหมุดบ้าน',
              ),
              onPressed: _pickHome,
            ),
            const SizedBox(height: 12),
            const Text('จ่ายค่าส่งให้ไรเดอร์'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cash', label: Text('เงินสด')),
                ButtonSegment(value: 'promptpay', label: Text('โอนพร้อมเพย์')),
              ],
              selected: {_deliveryPayment},
              onSelectionChanged: (s) => setState(() => _deliveryPayment = s.first),
            ),
          ],
          const SizedBox(height: 12),
          const Text('จ่ายค่าอาหารให้ร้าน'),
          SegmentedButton<String>(
            segments: [
              const ButtonSegment(value: 'promptpay', label: Text('สแกน QR')),
              if (widget.shop.acceptsCash) const ButtonSegment(value: 'cash', label: Text('เงินสด')),
            ],
            selected: {_foodPayment},
            onSelectionChanged: (s) => setState(() => _foodPayment = s.first),
          ),
          const Divider(height: 32),
          _row('ค่าอาหาร', baht(_food)),
          if (_fulfillment == 'delivery') _row('ค่าส่ง', baht(fee)),
          _row('รวม', baht(_food + fee), bold: true),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _place,
            child: Text(_when == null ? 'สั่งอาหาร' : 'จองอาหาร ${slotLabel(_when!)} น.'),
          ),
        ],
      ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : null, fontSize: bold ? 18 : null);
    return Row(
      children: [
        Expanded(child: Text(a, style: style)),
        Text(b, style: style),
      ],
    );
  }
}
