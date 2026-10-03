import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../widgets/common.dart';
import '../home_router.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('ผู้ดูแลระบบ'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'ร้านค้า'),
            Tab(text: 'ไรเดอร์'),
            Tab(text: 'ค่าส่ง'),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: const TabBarView(children: [_Shops(), _Riders(), _Zones()]),
    ),
  );
}

// ---------------------------------------------------------------- shops

class _Shops extends StatelessWidget {
  const _Shops();

  @override
  Widget build(BuildContext context) => Loader<List<Shop>>(
    load: Api.allShops,
    builder: (context, shops, reload) => Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            ListTile(title: Text('ร้านทั้งหมด ${shops.length} ร้าน')),
            for (final s in shops)
              SwitchListTile(
                title: Text(s.name),
                subtitle: Text('พร้อมเพย์ ${s.promptpayId} · ${s.isOpen ? 'เปิดอยู่' : 'ปิดอยู่'}'),
                value: s.isActive,
                onChanged: (v) async {
                  if (await guard(context, () => Api.updateShop(s.id, {'is_active': v}))) reload();
                },
              ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            icon: const Icon(Icons.add_business),
            label: const Text('เพิ่มร้าน'),
            onPressed: () async {
              final ok = await showDialog<bool>(context: context, builder: (_) => const _AddShop());
              if (ok == true) reload();
            },
          ),
        ),
      ],
    ),
  );
}

/// Admin adds a shop for an owner who has already signed up in the app.
class _AddShop extends StatefulWidget {
  const _AddShop();

  @override
  State<_AddShop> createState() => _AddShopState();
}

class _AddShopState extends State<_AddShop> {
  final _ownerPhone = TextEditingController();
  final _name = TextEditingController();
  final _promptpay = TextEditingController();

  Future<void> _save() async {
    final ok = await guard(context, () async {
      final owners = await Api.findProfileByPhone(_ownerPhone.text.trim());
      if (owners.isEmpty) throw 'ไม่พบสมาชิกเบอร์นี้ ให้เจ้าของร้านสมัครสมาชิกในแอปก่อน';
      final ownerId = owners.first['id'] as String;
      if (owners.first['role'] == 'customer') await Api.setRole(ownerId, 'shop_owner');
      await Api.createShop({
        'owner_id': ownerId,
        'name': _name.text.trim(),
        'promptpay_id': _promptpay.text.trim(),
        'phone': Api.digitsOnly(_ownerPhone.text),
      });
    }, done: 'เพิ่มร้านแล้ว');
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('เพิ่มร้านค้า'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _ownerPhone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'เบอร์โทรเจ้าของร้าน (ที่ใช้สมัคร)'),
        ),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'ชื่อร้าน'),
        ),
        TextField(
          controller: _promptpay,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'พร้อมเพย์ของร้าน'),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
      FilledButton(onPressed: _save, child: const Text('บันทึก')),
    ],
  );
}

// ---------------------------------------------------------------- riders

class _Riders extends StatelessWidget {
  const _Riders();

  static const _statusLabel = {
    'pending_approval': 'รออนุมัติ',
    'approved': 'อนุมัติแล้ว',
    'suspended': 'ระงับ',
  };

  Future<void> _showDoc(BuildContext context, String? path) async {
    if (path == null) return;
    final url = await Api.riderDocUrl(path);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(child: Image.network(url)),
    );
  }

  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
    load: Api.riders,
    builder: (context, riders, reload) => riders.isEmpty
        ? const Empty('ยังไม่มีผู้สมัครไรเดอร์')
        : ListView(
            children: [
              for (final r in riders)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r['profiles']?['full_name'] ?? '-'} · ${r['profiles']?['phone'] ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${r['vehicle_type'] ?? ''} ${r['plate_no'] ?? ''} · พร้อมเพย์ ${r['promptpay_id']}',
                        ),
                        Text(
                          'สถานะ: ${_statusLabel[r['status']]}${r['is_online'] == true ? ' · ออนไลน์' : ''}',
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => _showDoc(context, r['id_card_image_url']),
                              child: const Text('ดูบัตรประชาชน'),
                            ),
                            TextButton(
                              onPressed: () => _showDoc(context, r['photo_url']),
                              child: const Text('ดูรูปถ่าย'),
                            ),
                            if (r['status'] != 'approved')
                              FilledButton(
                                onPressed: () async {
                                  if (await guard(context, () => Api.setRiderStatus(r['id'], 'approved'))) {
                                    reload();
                                  }
                                },
                                child: const Text('อนุมัติ'),
                              ),
                            if (r['status'] != 'suspended')
                              OutlinedButton(
                                onPressed: () async {
                                  if (await guard(context, () => Api.setRiderStatus(r['id'], 'suspended'))) {
                                    reload();
                                  }
                                },
                                child: const Text('ระงับ'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
  );
}

// ---------------------------------------------------------------- zones

class _Zones extends StatelessWidget {
  const _Zones();

  Future<void> _edit(BuildContext context, VoidCallback reload, [DeliveryZone? z]) async {
    final name = TextEditingController(text: z?.name);
    final fee = TextEditingController(text: z?.fee.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(z == null ? 'เพิ่มโซนจัดส่ง' : 'แก้ไขโซน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'ชื่อโซน เช่น ทั้งหมู่บ้าน'),
            ),
            TextField(
              controller: fee,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ค่าส่ง (บาท)'),
            ),
          ],
        ),
        actions: [
          if (z != null)
            TextButton(
              onPressed: () async {
                if (await guard(ctx, () => Api.deleteZone(z.id)) && ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('ลบ', style: TextStyle(color: Colors.red)),
            ),
          FilledButton(
            onPressed: () async {
              final f = double.tryParse(fee.text.trim());
              if (name.text.trim().isEmpty || f == null) return;
              if (await guard(ctx, () => Api.saveZone(z?.id, name.text.trim(), f)) && ctx.mounted) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    if (ok == true) reload();
  }

  @override
  Widget build(BuildContext context) => Loader<List<DeliveryZone>>(
    load: Api.zones,
    builder: (context, zones, reload) => ListView(
      children: [
        for (final z in zones)
          ListTile(title: Text(z.name), trailing: Text(baht(z.fee)), onTap: () => _edit(context, reload, z)),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('เพิ่มโซน'),
          onTap: () => _edit(context, reload),
        ),
      ],
    ),
  );
}
