import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// All database and storage calls in one place.
class Api {
  Api._();

  static SupabaseClient get _db => Supabase.instance.client;
  static String? get uid => _db.auth.currentUser?.id;
  static String? get email => _db.auth.currentUser?.email;

  static const _orderSelect = '*, order_items(*)';

  // ---------------------------------------------------------------- auth

  /// Members sign up with a phone number. Supabase Auth logs in by email, so a phone number
  /// becomes `<digits>@phoneLoginDomain`; nothing is ever mailed there (email confirmation is off).
  static const phoneLoginDomain = 'cozy-melomakarona-cafbc6.netlify.app';

  /// Turns what the member typed (a phone number, or an email for older accounts) into the
  /// login email. Throws [FormatException] when it is neither.
  static String loginEmail(String phoneOrEmail) {
    final s = phoneOrEmail.trim().toLowerCase();
    if (s.contains('@')) return s;
    final digits = digitsOnly(s);
    if (digits.length < 9 || digits.length > 10) throw const FormatException('เบอร์โทรไม่ถูกต้อง');
    return '$digits@$phoneLoginDomain';
  }

  static Future<void> signIn(String phoneOrEmail, String password) =>
      _db.auth.signInWithPassword(email: loginEmail(phoneOrEmail), password: password);

  /// [signupAs] is what the member picked at sign-up (customer, shop or rider);
  /// the home screen uses it to open the shop application or rider form first.
  static Future<void> signUp(
    String phone,
    String password,
    String name, {
    String signupAs = 'customer',
  }) async {
    // Set before the call: the app switches to the home screen as soon as the session starts.
    justJoined = signupAs == 'customer';
    try {
      await _db.auth.signUp(
        email: loginEmail(phone),
        password: password,
        data: {'full_name': name, 'phone': digitsOnly(phone), 'signup_as': signupAs},
      );
    } catch (_) {
      justJoined = false;
      rethrow;
    }
  }

  /// True right after a customer signs up, until the welcome message has been shown.
  static bool justJoined = false;

  static String get signupAs => _db.auth.currentUser?.userMetadata?['signup_as'] as String? ?? 'customer';

  /// Phone numbers are stored and compared as digits only, so "081-234 5678" matches "0812345678".
  static String digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  static Future<void> signOut() => _db.auth.signOut();

  static Future<Map<String, dynamic>?> myProfile() =>
      _db.from('profiles').select().eq('id', uid!).maybeSingle();

  static Future<void> updateProfile(Map<String, dynamic> fields) =>
      _db.from('profiles').update(fields).eq('id', uid!);

  // ---------------------------------------------------------------- shops & menu

  static Future<List<Shop>> openShops() async {
    final rows = await _db
        .from('shops')
        .select()
        .eq('is_active', true)
        .order('is_open', ascending: false)
        .order('name');
    return rows.map(Shop.fromRow).toList();
  }

  static Future<List<Shop>> allShops() async {
    final rows = await _db.from('shops').select().order('name');
    return rows.map(Shop.fromRow).toList();
  }

  static Future<Shop?> myShop() async {
    final row = await _db.from('shops').select().eq('owner_id', uid!).maybeSingle();
    return row == null ? null : Shop.fromRow(row);
  }

  static Future<Shop> shop(String id) async =>
      Shop.fromRow(await _db.from('shops').select().eq('id', id).single());

  static Future<void> updateShop(String id, Map<String, dynamic> fields) =>
      _db.from('shops').update(fields).eq('id', id);

  static Future<void> createShop(Map<String, dynamic> fields) => _db.from('shops').insert(fields);

  /// A member's request to open a shop; stays hidden until the admin approves it.
  static Future<void> applyForShop(Map<String, dynamic> fields) => _db.from('shops').insert({
    ...fields,
    'owner_id': uid,
    'status': 'pending',
    'is_active': false,
    'is_open': false,
    'submitted_at': DateTime.now().toUtc().toIso8601String(),
  });

  /// Edits a pending application, or sends a rejected one back for review.
  static Future<void> resubmitShop(String id, Map<String, dynamic> fields) => _db
      .from('shops')
      .update({...fields, 'status': 'pending', 'submitted_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id);

  /// Admin only: approve (shop goes live, owner gets the shop screen) or reject with a reason.
  static Future<void> reviewShop(String id, bool approve, String? note) =>
      _db.rpc('review_shop', params: {'p_shop_id': id, 'p_approve': approve, 'p_note': note});

  /// A shop with its owner's name and phone, for the admin's review screen.
  static Future<(Shop, Map<String, dynamic>?)> shopForReview(String id) async {
    final row = await _db
        .from('shops')
        .select('*, profiles!shops_owner_id_fkey(full_name, phone)')
        .eq('id', id)
        .single();
    return (Shop.fromRow(row), row['profiles'] as Map<String, dynamic>?);
  }

  static Future<int> menuCount(String shopId) async =>
      (await _db.from('menu_items').select('id').eq('shop_id', shopId)).length;

  static Future<List<MenuItem>> menu(String shopId) async {
    final rows = await _db
        .from('menu_items')
        .select()
        .eq('shop_id', shopId)
        .order('sort_order')
        .order('name');
    return rows.map(MenuItem.fromRow).toList();
  }

  static Future<void> saveMenuItem(String? id, Map<String, dynamic> fields) =>
      id == null ? _db.from('menu_items').insert(fields) : _db.from('menu_items').update(fields).eq('id', id);

  static Future<void> deleteMenuItem(String id) => _db.from('menu_items').delete().eq('id', id);

  static Future<String> uploadImage(Uint8List bytes) async {
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage
        .from('images')
        .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    return _db.storage.from('images').getPublicUrl(path);
  }

  // ---------------------------------------------------------------- zones

  static Future<List<DeliveryZone>> zones() async {
    final rows = await _db.from('delivery_zones').select().order('name');
    return rows.map(DeliveryZone.fromRow).toList();
  }

  static Future<void> saveZone(String? id, String name, double fee) => id == null
      ? _db.from('delivery_zones').insert({'name': name, 'fee': fee})
      : _db.from('delivery_zones').update({'name': name, 'fee': fee}).eq('id', id);

  static Future<void> deleteZone(String id) => _db.from('delivery_zones').delete().eq('id', id);

  // ---------------------------------------------------------------- orders

  static Future<String> placeOrder({
    required String shopId,
    required List<CartLine> cart,
    required String fulfillment,
    String? zoneId,
    required String foodPayment,
    required String deliveryPayment,
    String? addressNote,
  }) async {
    final id = await _db.rpc(
      'place_order',
      params: {
        'p_shop_id': shopId,
        'p_items': [
          for (final l in cart) {'menu_item_id': l.item.id, 'qty': l.qty, 'note': l.note},
        ],
        'p_fulfillment': fulfillment,
        'p_zone_id': zoneId,
        'p_food_payment': foodPayment,
        'p_delivery_payment': deliveryPayment,
        'p_address_note': addressNote,
      },
    );
    return id as String;
  }

  static Future<void> setDropoff(String orderId, double lat, double lng) =>
      _db.rpc('set_order_dropoff', params: {'p_order_id': orderId, 'p_lat': lat, 'p_lng': lng});

  static Future<void> updateRiderLocation(String orderId, double lat, double lng) =>
      _db.rpc('update_rider_location', params: {'p_order_id': orderId, 'p_lat': lat, 'p_lng': lng});

  static Future<void> saveHomePin(double lat, double lng) =>
      _db.from('profiles').update({'home_lat': lat, 'home_lng': lng}).eq('id', uid!);

  static Future<Order> order(String id) async =>
      Order.fromRow(await _db.from('orders').select(_orderSelect).eq('id', id).single());

  static Future<List<Order>> myOrders() async {
    final rows = await _db
        .from('orders')
        .select(_orderSelect)
        .eq('customer_id', uid!)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(Order.fromRow).toList();
  }

  static Future<List<Order>> shopOrders(String shopId) async {
    final rows = await _db
        .from('orders')
        .select(_orderSelect)
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map(Order.fromRow).toList();
  }

  /// Unclaimed delivery jobs (RLS only returns them to approved, online riders).
  static Future<List<Order>> openJobs() async {
    final rows = await _db
        .from('orders')
        .select(_orderSelect)
        .isFilter('rider_id', null)
        .eq('fulfillment', 'delivery')
        .inFilter('status', ['accepted', 'cooking', 'ready'])
        .order('created_at');
    return rows.map(Order.fromRow).toList();
  }

  static Future<List<Order>> myDeliveries() async {
    final rows = await _db
        .from('orders')
        .select(_orderSelect)
        .eq('rider_id', uid!)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(Order.fromRow).toList();
  }

  /// Fires whenever any order this user can see changes; screens reload on it.
  static Stream<void> orderChanges() => _db.from('orders').stream(primaryKey: ['id']).map((_) {});

  static Future<void> setStatus(String orderId, String status) =>
      _db.rpc('set_order_status', params: {'p_order_id': orderId, 'p_status': status});

  static Future<bool> claim(String orderId) async =>
      await _db.rpc('claim_order', params: {'p_order_id': orderId}) as bool;

  static Future<void> uploadSlip(String orderId, Uint8List bytes) async {
    final path = '$uid/$orderId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage
        .from('slips')
        .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    await _db.rpc('submit_slip', params: {'p_order_id': orderId, 'p_path': path});
  }

  static Future<String> slipUrl(String path) => _db.storage.from('slips').createSignedUrl(path, 3600);

  static Future<void> reviewPayment(String orderId, bool ok) =>
      _db.rpc('review_payment', params: {'p_order_id': orderId, 'p_ok': ok});

  // ---------------------------------------------------------------- riders

  static Future<Map<String, dynamic>?> myRider() => _db.from('riders').select().eq('id', uid!).maybeSingle();

  static Future<void> registerRider({
    required String promptpayId,
    required String vehicleType,
    required String plateNo,
    required Uint8List idCard,
    required Uint8List photo,
  }) async {
    Future<String> up(String name, Uint8List b) async {
      final path = '$uid/$name.jpg';
      await _db.storage
          .from('rider-docs')
          .uploadBinary(path, b, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
      return path;
    }

    await _db.from('riders').insert({
      'id': uid,
      'promptpay_id': promptpayId,
      'vehicle_type': vehicleType,
      'plate_no': plateNo,
      'id_card_image_url': await up('id-card', idCard),
      'photo_url': await up('photo', photo),
    });
  }

  static Future<void> setOnline(bool online) =>
      _db.from('riders').update({'is_online': online}).eq('id', uid!);

  static Future<Map<String, dynamic>?> riderPublic(String id) =>
      _db.from('profiles').select('full_name, phone').eq('id', id).maybeSingle();

  static Future<String?> riderPromptPay(String id) async =>
      (await _db.from('riders').select('promptpay_id').eq('id', id).maybeSingle())?['promptpay_id'];

  // ---------------------------------------------------------------- admin

  static Future<List<Map<String, dynamic>>> riders() =>
      _db.from('riders').select('*, profiles(full_name, phone)').order('created_at', ascending: false);

  static Future<void> setRiderStatus(String id, String status) =>
      _db.from('riders').update({'status': status}).eq('id', id);

  static Future<String> riderDocUrl(String path) =>
      _db.storage.from('rider-docs').createSignedUrl(path, 3600);

  /// Admin only (RLS). Compares digits so numbers saved with dashes or spaces still match.
  static Future<List<Map<String, dynamic>>> findProfileByPhone(String phone) async {
    final want = digitsOnly(phone);
    final rows = await _db.from('profiles').select().not('phone', 'is', null);
    return rows.where((r) => digitsOnly(r['phone'] as String) == want).toList();
  }

  /// Everyone who has signed up, newest first, with their rider application if any.
  static Future<List<Map<String, dynamic>>> members() => _db
      .from('profiles')
      .select(
        'id, full_name, phone, role, created_at, riders!riders_id_fkey(status), shops!shops_owner_id_fkey(id, status)',
      )
      .order('created_at', ascending: false)
      .limit(500);

  static Future<void> setRole(String userId, String role) =>
      _db.from('profiles').update({'role': role}).eq('id', userId);
}
