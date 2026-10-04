import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/alert/alert.dart' as alert;
import '../../core/api.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../core/order_watch.dart';
import '../../core/schedule.dart';

/// Rings, vibrates and pops up when a new order or payment slip arrives, while the shop has the app open.
/// Browsers only play sound after a tap, so on the web the bar asks the shop to switch the sound on first.
class OrderAlerts extends StatefulWidget {
  const OrderAlerts({super.key, required this.shop});
  final Shop shop;

  @override
  State<OrderAlerts> createState() => _OrderAlertsState();
}

class _OrderAlertsState extends State<OrderAlerts> {
  static const _repeatEvery = Duration(seconds: 15);
  static const _maxRings = 6;

  final _watcher = OrderWatcher();
  final _waiting = ValueNotifier<List<OrderEvent>>([]);
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  late final AppLifecycleListener _lifecycle;
  Timer? _repeat;
  bool _soundOn = !kIsWeb; // the Android app may play sound without a tap first
  bool _screenOn = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _sub = Api.shopOrderRows(widget.shop.id).listen(_onRows, onError: (_) {});
    // the browser drops the keep-screen-on request when the page is hidden; ask again on return
    _lifecycle = AppLifecycleListener(
      onResume: () async {
        if (_screenOn) _screenOn = await alert.keepScreenOn(true);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _repeat?.cancel();
    _lifecycle.dispose();
    alert.keepScreenOn(false);
    alert.setTitleCount(0);
    _waiting.dispose();
    super.dispose();
  }

  void _onRows(List<Map<String, dynamic>> rows) {
    final events = _watcher.update(rows);
    if (events.isEmpty || !mounted) return;
    _waiting.value = [..._waiting.value, ...events];
    alert.setTitleCount(_waiting.value.length);
    _ring();
    _repeat ??= Timer.periodic(_repeatEvery, (t) {
      if (t.tick >= _maxRings) t.cancel();
      _ring();
    });
    if (!_dialogOpen) _showDialog();
  }

  void _ring() {
    if (_soundOn) alert.playChime();
    alert.vibrate();
  }

  /// Stops the ringing and clears the count once the shop has seen it.
  void _acknowledge() {
    _repeat?.cancel();
    _repeat = null;
    _waiting.value = [];
    alert.setTitleCount(0);
  }

  Future<void> _showDialog() async {
    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<List<OrderEvent>>(
        valueListenable: _waiting,
        builder: (ctx, events, _) {
          final newOrders = events.where((e) => !e.isSlip).length;
          return AlertDialog(
            icon: Icon(
              newOrders > 0 ? Icons.notifications_active : Icons.receipt_long,
              size: 44,
              color: Theme.of(ctx).colorScheme.primary,
            ),
            title: Text(
              newOrders > 0
                  ? 'ออเดอร์ใหม่${newOrders > 1 ? ' $newOrders ออเดอร์' : ''}'
                  : 'ลูกค้าส่งสลิปแล้ว รอตรวจ',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final e in events) _EventLine(e)],
              ),
            ),
            actions: [
              FilledButton.icon(
                icon: const Icon(Icons.list_alt),
                label: const Text('ดูออเดอร์'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          );
        },
      ),
    );
    _dialogOpen = false;
    _acknowledge();
    if (mounted) DefaultTabController.maybeOf(context)?.animateTo(0);
  }

  Future<void> _turnOn() async {
    final ok = await alert.unlockSound();
    final screen = await alert.keepScreenOn(true);
    if (!mounted) return;
    setState(() {
      _soundOn = ok;
      _screenOn = screen;
    });
    if (ok) alert.playChime();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'เปิดเสียงแจ้งเตือนแล้ว เปิดหน้านี้ค้างไว้ มีออเดอร์ใหม่จะมีเสียงกริ่งดังขึ้น'
              : 'เปิดเสียงไม่สำเร็จ ลองกดอีกครั้ง และเช็กว่าไม่ได้ปิดเสียงเครื่อง',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!_soundOn) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.notifications_off),
            label: const Text('แตะเพื่อเปิดเสียงแจ้งเตือนออเดอร์ใหม่'),
            onPressed: _turnOn,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
      child: Row(
        children: [
          Icon(Icons.notifications_active, color: scheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _screenOn ? 'เสียงแจ้งเตือนเปิดอยู่ · หน้าจอไม่ดับ' : 'เสียงแจ้งเตือนเปิดอยู่',
              style: TextStyle(color: scheme.primary),
            ),
          ),
          TextButton(onPressed: _ring, child: const Text('ทดสอบเสียง')),
        ],
      ),
    );
  }
}

class _EventLine extends StatelessWidget {
  const _EventLine(this.event);
  final OrderEvent event;

  @override
  Widget build(BuildContext context) {
    final o = event.order;
    // the food total is filled in a moment after a new order appears, so only slips show an amount
    final when = o.scheduledFor == null ? 'สั่งเลย' : 'จองรับ ${slotLabel(o.scheduledFor!)} น.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        event.isSlip
            ? '#${o.shortId} · ส่งสลิปค่าอาหาร ${baht(o.foodTotal)} แล้ว กดดูสลิปแล้วยืนยันได้รับเงิน'
            : '#${o.shortId} · ${o.isDelivery ? 'ส่งถึงบ้าน' : 'มารับเองที่ร้าน'} · $when',
      ),
    );
  }
}
