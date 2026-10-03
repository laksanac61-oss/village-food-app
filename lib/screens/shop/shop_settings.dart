import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/promptpay.dart';
import '../../widgets/common.dart';

class ShopSettings extends StatefulWidget {
  const ShopSettings({super.key, required this.shop, required this.onSaved});
  final Shop shop;
  final VoidCallback onSaved;

  @override
  State<ShopSettings> createState() => _ShopSettingsState();
}

class _ShopSettingsState extends State<ShopSettings> {
  late final _name = TextEditingController(text: widget.shop.name);
  late final _desc = TextEditingController(text: widget.shop.description);
  late final _phone = TextEditingController(text: widget.shop.phone);
  late final _promptpay = TextEditingController(text: widget.shop.promptpayId);
  late bool _cash = widget.shop.acceptsCash;
  late String? _imageUrl = widget.shop.imageUrl;

  Future<void> _save() async {
    try {
      promptPayPayload(_promptpay.text);
    } on ArgumentError {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เลขพร้อมเพย์ต้องเป็นเบอร์มือถือ 10 หลัก หรือเลขบัตร 13 หลัก')),
      );
      return;
    }
    if (await guard(
      context,
      () => Api.updateShop(widget.shop.id, {
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'phone': _phone.text.trim(),
        'promptpay_id': _promptpay.text.trim(),
        'accepts_cash': _cash,
        'image_url': _imageUrl,
      }),
      done: 'บันทึกแล้ว',
    )) {
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundImage: _imageUrl == null ? null : NetworkImage(_imageUrl!),
            child: _imageUrl == null ? const Icon(Icons.store) : null,
          ),
          TextButton(
            onPressed: () async {
              final bytes = await pickPhoto();
              if (bytes == null || !context.mounted) return;
              await guard(context, () async {
                final url = await Api.uploadImage(bytes);
                setState(() => _imageUrl = url);
              });
            },
            child: const Text('เปลี่ยนรูปร้าน'),
          ),
        ],
      ),
      TextField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'ชื่อร้าน'),
      ),
      TextField(
        controller: _desc,
        decoration: const InputDecoration(labelText: 'คำอธิบายร้าน'),
      ),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'เบอร์โทรร้าน'),
      ),
      TextField(
        controller: _promptpay,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'พร้อมเพย์ (เบอร์มือถือ หรือ เลขบัตรประชาชน)',
          helperText: 'ลูกค้าจะสแกนจ่ายเข้าบัญชีนี้โดยตรง',
        ),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('รับเงินสด'),
        value: _cash,
        onChanged: (v) => setState(() => _cash = v),
      ),
      const SizedBox(height: 16),
      FilledButton(onPressed: _save, child: const Text('บันทึก')),
    ],
  );
}
