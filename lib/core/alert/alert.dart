// Getting a shop's attention when an order arrives: chime, vibration, tab title and keeping the screen on.
// The web build uses browser APIs; other platforms fall back to the system alert sound and haptics.
export 'alert_stub.dart' if (dart.library.js_interop) 'alert_web.dart';
