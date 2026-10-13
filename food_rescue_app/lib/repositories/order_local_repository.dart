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
  Future<void> updateOrderStatus(String orderId, OrderStatus status);
  Future<void> deleteOrder(String orderId);
  Future<void> clearAll();
}

class OrderLocalRepositoryImpl implements OrderLocalRepository {
  OrderLocalRepositoryImpl({this.prefsWithOverrides});

  /// Daftar SharedPreferences yang sudah di-override (dipakai saat test).
  final List<SharedPreferencesAsync>? prefsWithOverrides;

  static const _key = 'food_rescue_orders';

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

    if (raw == null || raw.isEmpty) return [];

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
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final orders = await loadOrders();
    final index = orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return;

    orders[index] = Order(
      id: orders[index].id,
      pickupCode: orders[index].pickupCode,
      buyerName: orders[index].buyerName,
      surplusFoodName: orders[index].surplusFoodName,
      quantity: orders[index].quantity,
      totalPrice: orders[index].totalPrice,
      status: status,
      createdAt: orders[index].createdAt,
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
