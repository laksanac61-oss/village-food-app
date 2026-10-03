import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../widgets/common.dart';

class ShopMenuAdmin extends StatelessWidget {
  const ShopMenuAdmin({super.key, required this.shop, this.onFirstItem});
  final Shop shop;

  /// Called when the first menu item is added, so the shop's getting-started card updates.
  final VoidCallback? onFirstItem;

  Future<void> _edit(
    BuildContext context,
    VoidCallback reload, {
    MenuItem? item,
    bool wasEmpty = false,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MenuForm(shopId: shop.id, item: item),
    );
    if (saved != true) return;
    reload();
    if (wasEmpty) onFirstItem?.call();
  }

  @override
  Widget build(BuildContext context) => Loader<List<MenuItem>>(
    load: () => Api.menu(shop.id),
    builder: (context, menu, reload) => Stack(
      children: [
        menu.isEmpty
            ? const Empty('ยังไม่มีเมนู กด + เพื่อเพิ่ม')
            : ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  for (final m in menu)
                    ListTile(
                      leading: m.imageUrl == null
                          ? const Icon(Icons.fastfood)
                          : Image.network(m.imageUrl!, width: 48, height: 48, fit: BoxFit.cover),
                      title: Text(m.name),
                      subtitle: Text(baht(m.price)),
                      onTap: () => _edit(context, reload, item: m),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.isAvailable ? 'มีขาย' : 'หมด'),
                          Switch(
                            value: m.isAvailable,
                            onChanged: (v) async {
                              if (await guard(context, () => Api.saveMenuItem(m.id, {'is_available': v}))) {
                                reload();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _edit(context, reload, wasEmpty: menu.isEmpty),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    ),
  );
}

class _MenuForm extends StatefulWidget {
  const _MenuForm({required this.shopId, this.item});
  final String shopId;
  final MenuItem? item;

  @override
  State<_MenuForm> createState() => _MenuFormState();
}

class _MenuFormState extends State<_MenuForm> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _desc = TextEditingController(text: widget.item?.description);
  late final _price = TextEditingController(text: widget.item?.price.toStringAsFixed(0));
  late String? _imageUrl = widget.item?.imageUrl;
  bool _busy = false;

  Future<void> _save() async {
    final price = double.tryParse(_price.text.trim());
    if (_name.text.trim().isEmpty || price == null) return;
    setState(() => _busy = true);
    final ok = await guard(
      context,
      () => Api.saveMenuItem(widget.item?.id, {
        'shop_id': widget.shopId,
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'price': price,
        'image_url': _imageUrl,
      }),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.item == null ? 'เพิ่มเมนู' : 'แก้ไขเมนู', style: Theme.of(context).textTheme.titleLarge),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'ชื่อเมนู'),
        ),
        TextField(
          controller: _desc,
          decoration: const InputDecoration(labelText: 'รายละเอียด'),
        ),
        TextField(
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'ราคา (บาท)'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_imageUrl != null) Image.network(_imageUrl!, width: 56, height: 56, fit: BoxFit.cover),
            TextButton.icon(
              icon: const Icon(Icons.photo),
              label: const Text('เลือกรูป'),
              onPressed: () async {
                final bytes = await pickPhoto();
                if (bytes == null || !context.mounted) return;
                await guard(context, () async {
                  final url = await Api.uploadImage(bytes);
                  setState(() => _imageUrl = url);
                });
              },
            ),
            const Spacer(),
            if (widget.item != null)
              TextButton(
                onPressed: () async {
                  if (await guard(context, () => Api.deleteMenuItem(widget.item!.id)) && context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('ลบ', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _busy ? null : _save, child: const Text('บันทึก')),
        ),
      ],
    ),
  );
}
