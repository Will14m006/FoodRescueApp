import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/order_model.dart';

abstract class OrderRepository {
  /// Buat pesanan. Harga dihitung server — klien tidak boleh menentukan total.
  Future<Order> createOrder({
    required String token,
    required int foodId,
    required int quantity,
  });

  Future<List<Order>> fetchOrders({required String token});

  /// Merchant memverifikasi kode pick-up milik pembeli.
  Future<Order> complete({
    required String token,
    required int orderId,
    required String pickupCode,
  });

  Future<Order> cancel({required String token, required int orderId});
}

class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository({required this.api});

  final ApiClient api;

  @override
  Future<Order> createOrder({
    required String token,
    required int foodId,
    required int quantity,
  }) async {
    final body = await api.request(
      method: 'POST',
      path: '/orders',
      token: token,
      body: {'foodId': foodId, 'quantity': quantity},
    );
    return _order(body);
  }

  @override
  Future<List<Order>> fetchOrders({required String token}) async {
    final body = await api.request(method: 'GET', path: '/orders', token: token);

    final orders = body['orders'];
    if (orders is! List) {
      throw const ApiException('Format daftar pesanan tidak sesuai.');
    }
    return orders
        .whereType<Map<String, dynamic>>()
        .map(Order.fromJson)
        .toList();
  }

  @override
  Future<Order> complete({
    required String token,
    required int orderId,
    required String pickupCode,
  }) async {
    final body = await api.request(
      method: 'POST',
      path: '/orders/$orderId/complete',
      token: token,
      body: {'pickupCode': pickupCode},
    );
    return _order(body);
  }

  @override
  Future<Order> cancel({required String token, required int orderId}) async {
    final body = await api.request(
      method: 'POST',
      path: '/orders/$orderId/cancel',
      token: token,
    );
    return _order(body);
  }

  Order _order(Map<String, dynamic> body) {
    final order = body['order'];
    if (order is! Map<String, dynamic>) {
      throw const ApiException('Format respons pesanan tidak sesuai.');
    }
    return Order.fromJson(order);
  }
}

/// Implementasi palsu untuk widget test (tanpa jaringan).
///
/// Bertindak seperti server kecil di memori: pesanan yang dibuat tersimpan,
/// `complete` memverifikasi kode, `cancel` mengubah status. Dengan begitu
/// alur booking -> status -> riwayat bisa diuji tanpa backend berjalan.
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository({this.delay = const Duration(milliseconds: 1500)});

  final Duration delay;
  final List<Order> _orders = [];
  int _counter = 100;

  /// Berapa kali [createOrder] dipanggil - dipakai test anti double-tap.
  int createCalls = 0;

  /// Jumlah porsi pada panggilan terakhir.
  int? lastQuantity;

  @override
  Future<Order> createOrder({
    required String token,
    required int foodId,
    required int quantity,
  }) async {
    createCalls += 1;
    lastQuantity = quantity;
    await Future<void>.delayed(delay);
    _counter += 1;

    final order = Order(
      id: _counter,
      pickupCode: 'RESCUE-${_counter.toString()}',
      buyerName: 'Pembeli',
      foodId: foodId,
      surplusFoodName: 'Paket Roti Sisa Hari Ini',
      merchantName: 'Roti O Bakso',
      quantity: quantity,
      totalPrice: 15000 * quantity,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );
    _orders.insert(0, order);
    return order;
  }

  @override
  Future<List<Order>> fetchOrders({required String token}) async =>
      List.unmodifiable(_orders);

  @override
  Future<Order> complete({
    required String token,
    required int orderId,
    required String pickupCode,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) throw const ApiException('Pesanan tidak ditemukan.');

    final order = _orders[index];
    if (order.pickupCode == null || order.pickupCode != pickupCode) {
      throw const ApiException('Kode pick-up tidak cocok.', statusCode: 422);
    }

    final updated = order.copyWith(status: OrderStatus.completed);
    _orders[index] = updated;
    return updated;
  }

  @override
  Future<Order> cancel({required String token, required int orderId}) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) throw const ApiException('Pesanan tidak ditemukan.');

    final updated = _orders[index].copyWith(status: OrderStatus.cancelled);
    _orders[index] = updated;
    return updated;
  }
}
