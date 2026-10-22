import 'dart:convert';

import 'package:http/http.dart' as http;

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
  ApiOrderRepository({http.Client? client, this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const endpoint = 'https://dummyjson.com/carts/add';

  @override
  Future<Order> createOrder({
    required String buyerName,
    required String surplusFoodId,
    required String surplusFoodName,
    required int quantity,
    required int unitPrice,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': 1,
              'products': [
                {
                  'id': int.tryParse(surplusFoodId) ?? 1,
                  'quantity': quantity,
                }
              ],
            }),
          )
          .timeout(timeout);
    } on Exception {
      throw const ApiException(
        'Tidak bisa terhubung ke server. Periksa koneksi internet kamu.',
      );
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        'Gagal menyimpan pesanan (error ${response.statusCode}). Coba lagi.',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ApiException('Respons server tidak dapat dibaca (JSON rusak).');
    }

    if (decoded is! Map<String, dynamic> || decoded['id'] == null) {
      throw const ApiException('Format respons server tidak sesuai.');
    }

    final serverId = decoded['id'];

    // dummyjson selalu mengembalikan id cart yang sama (209) untuk setiap POST,
    // jadi id/kode dari server tidak boleh dipakai mentah-mentah: dua pesanan
    // akan bertabrakan dan hanya pesanan pertama yang bisa diubah/dihapus.
    // Solusi: gabungkan id server + timestamp agar setiap pesanan unik,
    // dan tetap terbukti tersimpan di backend (request POST berhasil).
    final uniqueSuffix =
        DateTime.now().microsecondsSinceEpoch % 1000000;
    final orderId = 'ord-$serverId-$uniqueSuffix';
    final code = 'RESCUE-$serverId-$uniqueSuffix';

    return Order(
      id: orderId,
      pickupCode: code,
      buyerName: buyerName,
      surplusFoodName: surplusFoodName,
      quantity: quantity,
      totalPrice: unitPrice * quantity,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );
  }
}

/// Implementasi palsu (fake) untuk widget test.
///
/// Menghasilkan kode pick-up unik (contoh: RESCUE-101) sesuai arsitektur:
/// "Endpoint to create an order and generate a unique PickupCode".
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
