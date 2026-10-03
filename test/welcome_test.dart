import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_food/screens/home_router.dart';

void main() {
  testWidgets('welcome message closes with OK', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog(context: context, builder: (_) => const WelcomeDialog()),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('คุณเป็นสมาชิก ส่งอาหารบ้านดุง แล้ว'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeDialog), findsNothing);
  });
}
