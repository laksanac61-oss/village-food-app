import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
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

  @override
  void initState() {
    super.initState();
    Api.myProfile().then((p) {
      if (p == null || !mounted || _address.text.isNotEmpty) return;
      _address.text = [p['house_no'], p['soi']].where((s) => (s ?? '').isNotEmpty).join(' ');
      if (p['home_lat'] != null && p['home_lng'] != null) {
        setState(() => _home = LatLng((p['home_lat'] as num).toDouble(), (p['home_lng'] as num).toDouble()));
      }
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

  double get _food => widget.cart.fold(0, (s, l) => s + l.item.price * l.qty);

  Future<void> _place() async {
    if (_fulfillment == 'delivery' && (_zone == null || _address.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาเลือกโซนและใส่ที่อยู่สำหรับจัดส่ง')));
      return;
    }
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
            const SizedBox(height: 12),
            FutureBuilder<List<DeliveryZone>>(
              future: _zones,
              builder: (context, snap) => DropdownButtonFormField<DeliveryZone>(
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
            ),
            const SizedBox(height: 8),
            if (_home != null) OrderMap(dropoff: _home, height: 160),
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
          FilledButton(onPressed: _busy ? null : _place, child: const Text('สั่งอาหาร')),
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
