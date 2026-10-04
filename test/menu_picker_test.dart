import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_food/core/models.dart';
import 'package:village_food/screens/customer/shop_menu_screen.dart';

MenuItem _item(String id, String name, num price, {bool available = true}) =>
    MenuItem.fromRow({'id': id, 'shop_id': 's', 'name': name, 'price': price, 'is_available': available});

void main() {
  testWidgets('tapping a dish adds it, and the summary lists items with prices', (tester) async {
    final shop = Shop.fromRow({'id': 's', 'owner_id': 'o', 'name': 'ร้าน', 'promptpay_id': '0812345678'});
    List<CartLine>? sent;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuPicker(
            shop: shop,
            menu: [
              _item('a', 'ส้มตำไทย', 50),
              _item('b', 'ลาบหมู', 70),
              _item('c', 'ไก่ย่าง', 90, available: false),
            ],
            onConfirm: (cart) async {
              sent = cart;
              return true;
            },
          ),
        ),
      ),
    );

    expect(find.textContaining('ยืนยันรายการ'), findsNothing);
    await tester.tap(find.text('ส้มตำไทย'));
    await tester.tap(find.text('ส้มตำไทย'));
    await tester.tap(find.text('ลาบหมู'));
    await tester.tap(find.text('ไก่ย่าง')); // sold out: ignored
    await tester.pump();
    expect(find.text('×2'), findsOneWidget);
    expect(find.textContaining('ยืนยันรายการ (3)'), findsOneWidget);

    await tester.tap(find.textContaining('ยืนยันรายการ'));
    await tester.pumpAndSettle();
    expect(find.text('สรุปรายการอาหาร'), findsOneWidget);
    expect(find.textContaining('× 2 ='), findsOneWidget);
    expect(find.textContaining('170'), findsWidgets);

    await tester.tap(find.text('ยืนยัน ไปชำระเงิน'));
    await tester.pumpAndSettle();
    expect(sent!.map((l) => '${l.item.name}:${l.qty}'), ['ส้มตำไทย:2', 'ลาบหมู:1']);
    expect(find.textContaining('ยืนยันรายการ'), findsNothing); // order placed: cart cleared
  });
}
