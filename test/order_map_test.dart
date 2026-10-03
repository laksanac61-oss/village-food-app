import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:village_food/widgets/maps.dart';

void main() {
  testWidgets('swiping over a locked map scrolls the page; tapping unlocks it', (tester) async {
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              const SizedBox(height: 100),
              const OrderMap(shop: LatLng(17.6995, 103.2602), height: 300),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(OrderMap), const Offset(0, -200));
    await tester.pump();
    expect(scroll.offset, greaterThan(100));

    scroll.jumpTo(0);
    await tester.pump();
    await tester.tap(find.byType(OrderMap));
    await tester.pump();
    expect(find.text('ล็อกแผนที่'), findsOneWidget);

    // Unlocked: the same swipe now moves the map, not the page.
    await tester.drag(find.byType(OrderMap), const Offset(0, -200));
    await tester.pump();
    expect(scroll.offset, 0);

    await tester.tap(find.text('ล็อกแผนที่'));
    await tester.pump();
    expect(find.text('แตะเพื่อเลื่อน/ซูมแผนที่'), findsOneWidget);
  });
}
