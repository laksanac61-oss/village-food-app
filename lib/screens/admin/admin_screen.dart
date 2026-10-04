import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../widgets/common.dart';
import '../home_router.dart';
import 'shop_review.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('ผู้ดูแลระบบ'),
        bottom: TabBar(
          isScrollable: true,
          tabs: [
            const Tab(text: 'สมาชิก'),
            Tab(
              child: FutureBuilder<List<Shop>>(
                future: Api.allShops(),
                builder: (context, snap) {
                  final waiting = snap.data?.where((s) => s.isPending).length ?? 0;
                  return Badge(
                    isLabelVisible: waiting > 0,
                    label: Text('$waiting'),
                    child: const Padding(padding: EdgeInsets.only(right: 8), child: Text('ร้านค้า')),
                  );
                },
              ),
            ),
            Tab(
              child: FutureBuilder<int>(
                future: Api.riders().then(
                  (r) async =>
                      r.where((x) => x['status'] == 'pending_approval').length +
                      (await Api.ridersWithoutDocs()).length,
                ),
                builder: (context, snap) => Badge(
                  isLabelVisible: (snap.data ?? 0) > 0,
                  label: Text('${snap.data ?? 0}'),
                  child: const Padding(padding: EdgeInsets.only(right: 8), child: Text('ไรเดอร์')),
                ),
              ),
            ),
            const Tab(text: 'ค่าส่ง'),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: const TabBarView(children: [_Members(), _Shops(), _Riders(), _Zones()]),
    ),
  );
}

// ---------------------------------------------------------------- members

/// Everyone who has signed up, newest first, so the admin can spot new shop owners and riders.
class _Members extends StatefulWidget {
  const _Members();

  @override
  State<_Members> createState() => _MembersState();
}

class _MembersState extends State<_Members> {
  String _query = '';

  static const _roleLabel = {
    'customer': 'ลูกค้า',
    'shop_owner': 'เจ้าของร้าน',
    'rider': 'ไรเดอร์',
    'admin': 'แอดมิน',
  };

  static const _riderLabel = {
    'pending_approval': 'สมัครไรเดอร์ รออนุมัติ',
    'approved': 'ไรเดอร์',
    'suspended': 'ไรเดอร์ (ระงับ)',
  };

  static String _when(DateTime t) {
    final d = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year + 543} ${two(d.hour)}:${two(d.minute)}';
  }

  /// PostgREST returns a one-to-one embed as an object, but older versions return a list.
  static String? _riderStatus(Object? embed) => switch (embed) {
    {'status': final String s} => s,
    [{'status': final String s}, ...] => s,
    _ => null,
  };

  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
    load: Api.members,
    builder: (context, members, reload) {
      final q = _query.trim().toLowerCase();
      final shown = q.isEmpty
          ? members
          : members
                .where(
                  (m) =>
                      (m['full_name'] as String? ?? '').toLowerCase().contains(q) ||
                      (m['phone'] as String? ?? '').contains(
                        Api.digitsOnly(q).isEmpty ? q : Api.digitsOnly(q),
                      ),
                )
                .toList();
      final newCount = members
          .where((m) => DateTime.now().difference(DateTime.parse(m['created_at'])).inHours < 24)
          .length;
      return ListView(
        children: [
          ListTile(title: Text('สมาชิกทั้งหมด ${members.length} คน · ใหม่วันนี้ $newCount คน')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'ค้นหาชื่อหรือเบอร์',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          for (final m in shown) _tile(context, m, reload),
        ],
      );
    },
  );

  Widget _tile(BuildContext context, Map<String, dynamic> m, VoidCallback reload) {
    final created = DateTime.parse(m['created_at']);
    final isNew = DateTime.now().difference(created).inHours < 24;
    final rider = _riderStatus(m['riders']);
    final shops = m['shops'] is List ? m['shops'] as List : const [];
    final application = shops.isEmpty ? null : shops.first as Map<String, dynamic>;
    final phone = m['phone'] as String? ?? '';
    final tags = [
      if (!(m['role'] == 'rider' && rider != null)) _roleLabel[m['role']] ?? m['role'],
      if (rider != null && m['role'] != 'admin') _riderLabel[rider],
      if (rider == null && m['signup_as'] == 'rider' && m['role'] == 'customer')
        'ขอเป็นไรเดอร์ (ยังไม่ส่งเอกสาร)',
      if (application != null && application['status'] != 'approved')
        'ขอเปิดร้าน (${shopStatusLabel[application['status']]})',
    ];
    return ListTile(
      leading: CircleAvatar(child: Text((m['full_name'] as String? ?? '?').characters.firstOrNull ?? '?')),
      title: Row(
        children: [
          Flexible(child: Text(m['full_name'] ?? '-', overflow: TextOverflow.ellipsis)),
          if (isNew) ...[
            const SizedBox(width: 6),
            const Chip(label: Text('ใหม่'), visualDensity: VisualDensity.compact),
          ],
        ],
      ),
      subtitle: Text('$phone · ${tags.join(' · ')}\nสมัคร ${_when(created)}'),
      isThreeLine: true,
      onTap: application == null
          ? null
          : () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => ShopReviewScreen(shopId: application['id'])),
              );
              if (changed == true) reload();
            },
      trailing: m['role'] == 'customer' && phone.isNotEmpty && application == null
          ? TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => _AddShop(ownerPhone: phone),
                );
                if (ok == true) reload();
              },
              child: const Text('ตั้งเป็นร้าน'),
            )
          : null,
    );
  }
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
            if (shops.any((s) => s.isPending)) ...[
              ListTile(
                title: Text(
                  'คำขอเปิดร้าน รออนุมัติ ${shops.where((s) => s.isPending).length} ร้าน',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              for (final s in shops.where((s) => s.isPending)) _RequestTile(s, reload),
              const Divider(),
            ],
            if (shops.any((s) => s.isRejected)) ...[
              const ListTile(title: Text('ส่งกลับให้แก้ไข')),
              for (final s in shops.where((s) => s.isRejected)) _RequestTile(s, reload),
              const Divider(),
            ],
            ListTile(title: Text('ร้านที่อนุมัติแล้ว ${shops.where((s) => s.isApproved).length} ร้าน')),
            for (final s in shops.where((s) => s.isApproved))
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

/// A shop application in the admin's list; tap to see everything and approve or reject.
class _RequestTile extends StatelessWidget {
  const _RequestTile(this.shop, this.reload);
  final Shop shop;
  final VoidCallback reload;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: LogoAvatar(shop.imageUrl),
    title: Text(shop.name),
    subtitle: Text('${shop.category ?? '-'} · ${shopStatusLabel[shop.status]}'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () async {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => ShopReviewScreen(shopId: shop.id)),
      );
      if (changed == true) reload();
    },
  );
}

/// Admin adds a shop for an owner who has already signed up in the app.
class _AddShop extends StatefulWidget {
  const _AddShop({this.ownerPhone});
  final String? ownerPhone;

  @override
  State<_AddShop> createState() => _AddShopState();
}

class _AddShopState extends State<_AddShop> {
  late final _ownerPhone = TextEditingController(text: widget.ownerPhone);
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
    showPhoto(context, url);
  }

  static Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)> _load() async =>
      (await Api.riders(), await Api.ridersWithoutDocs());

  @override
  Widget build(BuildContext context) => Loader<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>(
    load: _load,
    builder: (context, data, reload) {
      final (riders, noDocs) = data;
      return riders.isEmpty && noDocs.isEmpty
          ? const Empty('ยังไม่มีผู้สมัครไรเดอร์')
          : ListView(
              children: [
                if (noDocs.isNotEmpty) ...[
                  const ListTile(
                    title: Text('สมัครเป็นไรเดอร์แล้ว แต่ยังไม่ส่งเอกสาร'),
                    subtitle: Text(
                      'ให้เข้าแอปแล้วกรอกพร้อมเพย์ ทะเบียนรถ แนบบัตรประชาชนและรูปถ่าย จึงจะอนุมัติได้',
                    ),
                  ),
                  for (final p in noDocs) _NoDocsTile(p),
                  const Divider(),
                ],
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
                                    if (await guard(
                                      context,
                                      () => Api.setRiderStatus(r['id'], 'suspended'),
                                    )) {
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
            );
    },
  );
}

class _NoDocsTile extends StatelessWidget {
  const _NoDocsTile(this.p);
  final Map<String, dynamic> p;

  @override
  Widget build(BuildContext context) {
    final phone = p['phone'] as String? ?? '';
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.two_wheeler)),
      title: Text(p['full_name'] ?? '-'),
      subtitle: Text('${phone.isEmpty ? '-' : phoneLabel(phone)} · รอส่งเอกสาร'),
      trailing: phone.isEmpty
          ? null
          : IconButton(
              tooltip: 'โทรหา',
              icon: const Icon(Icons.call),
              onPressed: () => launchUrl(Uri.parse('tel:$phone')),
            ),
    );
  }
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
