import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_model.dart';

/// Kontrak repository untuk penyimpanan lokal pesanan (P5: Local Data).
///
/// Implementasi memakai [SharedPreferences] yang menyimpan data dalam bentuk
/// JSON string. Di platform web storage-nya otomatis jatuh ke localStorage
/// browser, sedangkan di Android/iOS memakai SharedPreferences native.
abstract class OrderLocalRepository {
  Future<List<Order>> loadOrders();
  Future<void> saveOrder(Order order);
  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    String? proofPhoto,
  });
  Future<void> deleteOrder(String orderId);
  Future<void> clearAll();
}

class OrderLocalRepositoryImpl implements OrderLocalRepository {
  OrderLocalRepositoryImpl({this.prefsWithOverrides, this.userId});

  /// Daftar SharedPreferences yang sudah di-override (dipakai saat test).
  final List<SharedPreferencesAsync>? prefsWithOverrides;

  /// P10 fix #1: pesanan dipisah per akun. Dulu satu key global
  /// (`food_rescue_orders`) sehingga akun berikutnya di perangkat yang sama
  /// melihat pesanan akun sebelumnya.
  final int? userId;

  /// Key lama (device-wide). Hanya dibaca sekali untuk migrasi.
  static const _legacyKey = 'food_rescue_orders';

  static String keyFor(int? userId) =>
      userId == null ? 'food_rescue_orders_guest' : 'food_rescue_orders_u$userId';

  String get _key => keyFor(userId);

  Future<SharedPreferencesAsync> get _prefs async {
    if (prefsWithOverrides != null && prefsWithOverrides!.isNotEmpty) {
      return prefsWithOverrides!.first;
    }
    return SharedPreferencesAsync();
  }

  @override
  Future<List<Order>> loadOrders() async {
    final prefs = await _prefs;
    final raw = await prefs.getString(_key);

    if (raw == null || raw.isEmpty) {
      return _migrateLegacy(prefs);
    }

    return _decode(raw);
  }

  /// P10 fix #1: data dari versi lama (satu key untuk semua akun) dipindahkan
  /// ke key akun yang sedang login supaya riwayat pengguna tidak hilang.
  Future<List<Order>> _migrateLegacy(SharedPreferencesAsync prefs) async {
    final legacy = await prefs.getString(_legacyKey);
    if (legacy == null || legacy.isEmpty) return [];

    final orders = _decode(legacy);
    await prefs.setString(_key, legacy);
    await prefs.remove(_legacyKey);
    return orders;
  }

  List<Order> _decode(String raw) {
    final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;
    return jsonList
        .map((json) => Order.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAll(List<Order> orders) async {
    final prefs = await _prefs;
    final jsonList = orders.map((order) => order.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }

  @override
  Future<void> saveOrder(Order order) async {
    final orders = await loadOrders();
    orders.insert(0, order);
    await _writeAll(orders);
  }

  @override
  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    String? proofPhoto,
  }) async {
    final orders = await loadOrders();
    final index = orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return;

    orders[index] = orders[index].copyWith(
      status: status,
      proofPhoto: proofPhoto,
    );
    await _writeAll(orders);
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    final orders = await loadOrders();
    orders.removeWhere((order) => order.id == orderId);
    await _writeAll(orders);
  }

  @override
  Future<void> clearAll() async {
    await _writeAll([]);
  }
}
