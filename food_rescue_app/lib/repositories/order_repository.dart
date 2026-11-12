import 'package:http/http.dart' as http;

import '../core/network/api_client.dart';
import '../models/order_model.dart';
import 'surplus_food_repository.dart' show ApiException;

abstract class OrderRepository {
  Future<Order> createOrder({
    required String buyerName,
    required String surplusFoodId,
    required String surplusFoodName,
    required int quantity,
    required int unitPrice,
  });
}

/// P6: Penyimpanan pesanan ke backend sungguhan.
///
/// POST https://dummyjson.com/carts/add
/// - 200/201 + JSON valid -> [Order] dengan PickupCode dari server
/// - status lain          -> [ApiException] (HTTP gagal)
/// - body bukan JSON      -> [ApiException] (JSON rusak)
class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository({
    http.Client? client,
    Duration timeout = const Duration(seconds: 12),
    DateTime Function()? clock,
  })  : _api = ApiClient(client: client, timeout: timeout),
        _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final DateTime Function() _clock;

  static const endpoint = 'https://dummyjson.com/carts/add';

  @override
  Future<Order> createOrder({
    required String buyerName,
    required String surplusFoodId,
    required String surplusFoodName,
    required int quantity,
    required int unitPrice,
  }) async {
    final json = await _api.sendJson(
      method: 'POST',
      endpoint: endpoint,
      body: {
        'userId': 1,
        'products': [
          {'id': int.tryParse(surplusFoodId) ?? 1, 'quantity': quantity},
        ],
      },
      onError: (message, statusCode) => ApiException(
        statusCode == null
            ? message
            : 'Gagal menyimpan pesanan ($message). Coba lagi.',
      ),
    );

    final serverId = json['id'];
    if (serverId == null) {
      throw const ApiException('Format respons server tidak sesuai.');
    }

    // dummyjson selalu mengembalikan id cart yang sama (209) untuk tiap POST,
    // jadi id/kode dari server tidak boleh dipakai mentah-mentah: dua pesanan
    // akan bertabrakan dan hanya pesanan pertama yang bisa diubah.
    // Solusi: gabungkan id server + timestamp agar setiap pesanan unik.
    final uniqueSuffix = _clock().microsecondsSinceEpoch % 1000000;

    return Order(
      id: 'ord-$serverId-$uniqueSuffix',
      pickupCode: 'RESCUE-$serverId-$uniqueSuffix',
      buyerName: buyerName,
      surplusFoodName: surplusFoodName,
      quantity: quantity,
      totalPrice: unitPrice * quantity,
      status: OrderStatus.pending,
      createdAt: _clock(),
    );
  }
}

/// Implementasi palsu (fake) untuk widget test.
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository({this.delay = const Duration(milliseconds: 1500)});

  final Duration delay;
  int _counter = 100;

  @override
  Future<Order> createOrder({
    required String buyerName,
    required String surplusFoodId,
    required String surplusFoodName,
    required int quantity,
    required int unitPrice,
  }) async {
    await Future.delayed(delay);
    _counter += 1;

    return Order(
      id: 'ord-$_counter',
      pickupCode: 'RESCUE-$_counter',
      buyerName: buyerName,
      surplusFoodName: surplusFoodName,
      quantity: quantity,
      totalPrice: unitPrice * quantity,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );
  }
}
