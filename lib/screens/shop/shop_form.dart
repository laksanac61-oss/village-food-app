import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../core/promptpay.dart';
import '../../widgets/common.dart';
import '../../widgets/maps.dart';

/// Shop details: filled in when a member applies to open a shop, and edited later in shop settings.
class ShopForm extends StatefulWidget {
  const ShopForm({
    super.key,
    this.shop,
    this.defaultPhone,
    required this.requireDetails,
    required this.submitLabel,
    required this.onSubmit,
    this.header,
  });

  /// Shown above the form, e.g. the intro video card in shop settings.
  final Widget? header;

  final Shop? shop;
  final String? defaultPhone;

  /// Applications must include a storefront photo and a map pin; older shops may lack them.
  final bool requireDetails;
  final String submitLabel;
  final Future<void> Function(Map<String, dynamic> fields) onSubmit;

  @override
  State<ShopForm> createState() => _ShopFormState();
}

class _ShopFormState extends State<ShopForm> {
  late final _name = TextEditingController(text: widget.shop?.name);
  late final _desc = TextEditingController(text: widget.shop?.description);
  late final _phone = TextEditingController(text: widget.shop?.phone ?? widget.defaultPhone);
  late final _promptpay = TextEditingController(text: widget.shop?.promptpayId ?? widget.defaultPhone);
  late final _hours = TextEditingController(text: widget.shop?.openingHours);
  late final _address = TextEditingController(text: widget.shop?.address);
  late String? _category = widget.shop?.category;
  late bool _cash = widget.shop?.acceptsCash ?? true;
  late String? _logoUrl = widget.shop?.imageUrl;
  late String? _coverUrl = widget.shop?.coverUrl;
  late LatLng? _location = widget.shop?.location;
  bool _busy = false;

  String? _problem() {
    if (_name.text.trim().isEmpty) return 'กรุณากรอกชื่อร้าน';
    if (_category == null) return 'กรุณาเลือกประเภทอาหาร';
    final phone = Api.digitsOnly(_phone.text);
    if (phone.length < 9 || phone.length > 10) return 'เบอร์โทรร้านไม่ถูกต้อง';
    try {
      promptPayPayload(_promptpay.text);
    } on ArgumentError {
      return 'เลขพร้อมเพย์ต้องเป็นเบอร์มือถือ 10 หลัก หรือเลขบัตรประชาชน 13 หลัก';
    }
    if (widget.requireDetails) {
      if (_coverUrl == null) return 'กรุณาเพิ่มรูปหน้าร้าน';
      if (_location == null) return 'กรุณาปักหมุดตำแหน่งร้านบนแผนที่';
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _problem();
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _busy = true);
    await guard(
      context,
      () => widget.onSubmit({
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'category': _category,
        'phone': Api.digitsOnly(_phone.text),
        'promptpay_id': _promptpay.text.trim(),
        'accepts_cash': _cash,
        'opening_hours': _hours.text.trim(),
        'address': _address.text.trim(),
        'lat': _location?.latitude,
        'lng': _location?.longitude,
        'image_url': _logoUrl,
        'cover_url': _coverUrl,
      }),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickImage(void Function(String url) set, {double maxSide = 1280}) async {
    final bytes = await pickPhoto(maxSide: maxSide);
    if (bytes == null || !mounted) return;
    await guard(context, () async {
      final url = await Api.uploadImage(bytes);
      setState(() => set(url));
    });
  }

  Future<void> _pickLocation() async {
    final p = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => PinPickerScreen(
          initial: _location,
          title: 'ปักหมุดร้าน',
          hint: 'แตะบนแผนที่ตรงที่ตั้งร้าน',
          icon: Icons.storefront,
        ),
      ),
    );
    if (p != null) setState(() => _location = p);
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    children: [
      ?widget.header,
      _heading('ข้อมูลร้านที่ลูกค้าจะเห็น'),
      TextField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'ชื่อร้าน *'),
      ),
      DropdownButtonFormField<String>(
        initialValue: shopCategories.contains(_category) ? _category : null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'ประเภทอาหาร *'),
        items: [for (final c in shopCategories) DropdownMenuItem(value: c, child: Text(c))],
        onChanged: (v) => setState(() => _category = v),
      ),
      TextField(
        controller: _desc,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'แนะนำร้าน / เมนูเด่น',
          hintText: 'เช่น ก๋วยเตี๋ยวต้มยำสูตรเด็ด',
        ),
      ),
      TextField(
        controller: _hours,
        decoration: const InputDecoration(
          labelText: 'เวลาเปิด-ปิด',
          hintText: 'เช่น 07:00-15:00 หยุดวันจันทร์',
        ),
      ),
      _heading('รูปร้าน'),
      Row(
        children: [
          LogoAvatar(_logoUrl, radius: 36),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.add_a_photo),
            label: Text(_logoUrl == null ? 'เพิ่มโลโก้หรือรูปอาหาร' : 'เปลี่ยนโลโก้'),
            // A logo is shown small, so a smaller file is plenty.
            onPressed: () => _pickImage((u) => _logoUrl = u, maxSide: 600),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_coverUrl == null)
                ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo, size: 40),
                      Text(widget.requireDetails ? 'แตะเพื่อเพิ่มรูปหน้าร้าน *' : 'แตะเพื่อเพิ่มรูปหน้าร้าน'),
                      const Text('แนะนำถ่ายแนวนอน ให้เห็นป้ายร้าน', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                )
              else
                NetPhoto(_coverUrl!),
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: () => _pickImage((u) => _coverUrl = u)),
              ),
              if (_coverUrl != null)
                const Positioned(
                  right: 8,
                  bottom: 8,
                  child: IgnorePointer(
                    child: Chip(avatar: Icon(Icons.photo_camera, size: 18), label: Text('เปลี่ยนรูป')),
                  ),
                ),
            ],
          ),
        ),
      ),
      _heading('ที่ตั้งร้าน'),
      TextField(
        controller: _address,
        decoration: const InputDecoration(
          labelText: 'ที่อยู่ / จุดสังเกต',
          hintText: 'เช่น บ้านเลขที่ 12 หมู่ 3 ใกล้วัด',
        ),
      ),
      const SizedBox(height: 8),
      if (_location != null) ...[OrderMap(shop: _location, height: 160), const SizedBox(height: 4)],
      OutlinedButton.icon(
        icon: const Icon(Icons.location_on),
        label: Text(_location == null ? 'ปักหมุดตำแหน่งร้าน (GPS) *' : 'ย้ายหมุดตำแหน่งร้าน'),
        onPressed: _pickLocation,
      ),
      _heading('การติดต่อและรับเงิน'),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'เบอร์โทรร้าน *'),
      ),
      TextField(
        controller: _promptpay,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'พร้อมเพย์สำหรับรับเงิน *',
          helperText: 'เบอร์มือถือ หรือ เลขบัตรประชาชน ลูกค้าจะสแกนจ่ายเข้าบัญชีนี้โดยตรง',
        ),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('รับเงินสดด้วย'),
        value: _cash,
        onChanged: (v) => setState(() => _cash = v),
      ),
      const SizedBox(height: 16),
      FilledButton(onPressed: _busy ? null : _submit, child: Text(widget.submitLabel)),
      const SizedBox(height: 24),
    ],
  );
}
