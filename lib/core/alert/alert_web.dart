import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

const _title = 'ส่งอาหารบ้านดุง';
final _chime = web.HTMLAudioElement()
  ..src = 'assets/assets/sounds/new_order.wav'
  ..preload = 'auto';
JSObject? _wakeLock;

/// Browsers block sound until the page is tapped, so this runs from a button: a silent play unlocks it.
Future<bool> unlockSound() async {
  try {
    _chime.muted = true;
    await _chime.play().toDart;
    _chime.pause();
    _chime.currentTime = 0;
    _chime.muted = false;
    return true;
  } catch (_) {
    _chime.muted = false;
    return false;
  }
}

void playChime() {
  _chime.currentTime = 0;
  _chime.play().toDart.ignore();
}

void vibrate() {
  try {
    web.window.navigator.vibrate([400, 150, 400, 150, 400].map((e) => e.toJS).toList().toJS);
  } catch (_) {} // not every browser can vibrate
}

void setTitleCount(int count) => web.document.title = count > 0 ? '($count) ออเดอร์ใหม่ · $_title' : _title;

Future<bool> keepScreenOn(bool on) async {
  try {
    if (!on) {
      final lock = _wakeLock;
      _wakeLock = null;
      if (lock != null) await (lock.callMethod<JSPromise>('release'.toJS)).toDart;
      return false;
    }
    final wakeLock = (web.window.navigator as JSObject).getProperty<JSObject?>('wakeLock'.toJS);
    if (wakeLock == null) return false;
    _wakeLock = await (wakeLock.callMethod<JSPromise<JSObject>>('request'.toJS, 'screen'.toJS)).toDart;
    return true;
  } catch (_) {
    return false;
  }
}
