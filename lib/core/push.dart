import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Phone notifications (Firebase Cloud Messaging) in the Android app: new orders and payment slips reach
/// the shop even when the app is closed. The database sends them through the notify-shop Edge Function to
/// the device tokens saved here. The web app keeps its in-page chime instead.
class Push {
  // Firebase project "ban-dung-food" (values from google-services.json; not secret)
  static const _options = FirebaseOptions(
    apiKey: 'AIzaSyCLgyRwSqsvvEKJzov2Q3JsJy33rSmyvwM',
    appId: '1:950440190853:android:f71a0cb69e06136c679aec',
    messagingSenderId: '950440190853',
    projectId: 'ban-dung-food',
    storageBucket: 'ban-dung-food.firebasestorage.app',
  );

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String? _token;
  static bool _listening = false;

  static SupabaseClient get _db => Supabase.instance.client;

  /// Asks for permission to show notifications and saves this phone's token for the signed-in account.
  static Future<void> register() async {
    if (!supported || _db.auth.currentUser == null) return;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: _options);
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      _token = await fm.getToken();
      if (_token != null) await _save(_token!);
      if (!_listening) {
        _listening = true;
        fm.onTokenRefresh.listen((t) {
          _token = t;
          if (_db.auth.currentUser != null) _save(t);
        });
      }
    } catch (e) {
      debugPrint('push register failed: $e');
    }
  }

  static Future<void> _save(String token) =>
      _db.rpc('save_push_token', params: {'p_token': token, 'p_platform': 'android'});

  /// Before signing out, so this phone stops getting the account's notifications.
  static Future<void> forget() async {
    final t = _token;
    if (!supported || t == null) return;
    try {
      await _db.rpc('forget_push_token', params: {'p_token': t});
    } catch (e) {
      debugPrint('push forget failed: $e');
    }
  }
}
