import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import 'shop_form.dart';

class ShopSettings extends StatelessWidget {
  const ShopSettings({super.key, required this.shop, required this.onSaved});
  final Shop shop;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) => ShopForm(
    shop: shop,
    requireDetails: false,
    submitLabel: 'บันทึก',
    onSubmit: (fields) async {
      await Api.updateShop(shop.id, fields);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกแล้ว')));
      }
      onSaved();
    },
  );
}
