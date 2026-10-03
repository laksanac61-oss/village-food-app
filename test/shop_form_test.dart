import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_food/screens/shop/shop_form.dart';

void main() {
  Future<List<Map<String, dynamic>>> pump(WidgetTester tester, {required bool requireDetails}) async {
    final submitted = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShopForm(
            defaultPhone: '0812345678',
            requireDetails: requireDetails,
            submitLabel: 'ส่ง',
            onSubmit: (f) async => submitted.add(f),
          ),
        ),
      ),
    );
    return submitted;
  }

  Future<void> fillBasics(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextField, 'ชื่อร้าน *'), 'ส้มตำป้าแดง');
    await tester.tap(find.text('ประเภทอาหาร *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ก๋วยเตี๋ยว').last);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'ส่ง');
    await tester.scrollUntilVisible(button, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('application needs a name first', (tester) async {
    final submitted = await pump(tester, requireDetails: true);
    await submit(tester);
    expect(find.text('กรุณากรอกชื่อร้าน'), findsOneWidget);
    expect(submitted, isEmpty);
  });

  testWidgets('application needs a storefront photo', (tester) async {
    final submitted = await pump(tester, requireDetails: true);
    await fillBasics(tester);
    await submit(tester);
    expect(find.text('กรุณาเพิ่มรูปหน้าร้าน'), findsOneWidget);
    expect(submitted, isEmpty);
  });

  testWidgets('settings save without photo or pin', (tester) async {
    final submitted = await pump(tester, requireDetails: false);
    await fillBasics(tester);
    await submit(tester);
    expect(submitted, hasLength(1));
    expect(submitted.single['name'], 'ส้มตำป้าแดง');
    expect(submitted.single['category'], 'ก๋วยเตี๋ยว');
    expect(submitted.single['promptpay_id'], '0812345678');
  });
}
