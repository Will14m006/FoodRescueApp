// P6: Unit test Integrasi API & Model — kini menembak backend sendiri.
//
// Minimal 6 skenario yang diminta:
//   1. model valid
//   2. model invalid
//   3. API sukses
//   4. data kosong
//   5. HTTP gagal
//   6. JSON rusak
//
// Semua test memakai MockClient (in-memory) sehingga tidak butuh server
// berjalan dan hasilnya deterministik.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_rescue_app/core/network/api_client.dart';
import 'package:food_rescue_app/core/network/api_exception.dart';
import 'package:food_rescue_app/models/order_model.dart';
import 'package:food_rescue_app/models/surplus_food_model.dart';
import 'package:food_rescue_app/repositories/order_repository.dart';
import 'package:food_rescue_app/repositories/surplus_food_repository.dart';

/// Satu makanan valid sesuai `foodJson` di backend.
Map<String, dynamic> _validFood({
  int id = 16,
  String name = 'Roti Gandum',
  int originalPrice = 40000,
  int discountPrice = 15000,
  int quota = 8,
  bool isActive = true,
}) {
  return {
    'id': id,
    'merchantId': 3,
    'merchantName': 'Roti O Bakso',
    'name': name,
    'description': 'Isi 6 pcs roti varian klasik.',
    'originalPrice': originalPrice,
    'discountPrice': discountPrice,
    'quota': quota,
    'pickupWindow': '19:00 - 21:00',
    'isActive': isActive,
    'createdAt': '2026-11-20T10:00:00.000Z',
  };
}

/// Satu pesanan valid sesuai `orderJson` di backend.
Map<String, dynamic> _validOrder({
  int id = 42,
  String status = 'pending',
  int quantity = 2,
}) {
  return {
    'id': id,
    'pickupCode': 'RESCUE-7KQ2XM',
    'buyerId': 5,
    'buyerName': 'William',
    'foodId': 16,
    'foodName': 'Roti Gandum',
    'merchantName': 'Roti O Bakso',
    'quantity': quantity,
    'totalPrice': 15000 * quantity,
    'status': status,
    'createdAt': '2026-11-20T10:00:00.000Z',
  };
}

http.Response _json(Object body, [int status = 200]) {
  return http.Response(jsonEncode(body), status,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

ApiClient _api(MockClient client) =>
    ApiClient(client: client, baseUrl: 'http://test.local');

void main() {
  // ============================================================
  // 1. MODEL VALID
  // ============================================================
  test('model valid: SurplusFood.fromJson memetakan semua field', () {
    final food = SurplusFood.fromJson(_validFood());

    expect(food.id, 16);
    expect(food.merchantId, 3);
    expect(food.merchantName, 'Roti O Bakso');
    expect(food.name, 'Roti Gandum');
    expect(food.originalPrice, 40000);
    expect(food.discountPrice, 15000);
    expect(food.quota, 8);
    expect(food.pickupWindow, '19:00 - 21:00');
    expect(food.isActive, isTrue);
    expect(food.isAvailable, isTrue);
    // 40000 -> 15000 = 62.5% -> dibulatkan 63
    expect(food.discountPercent, 63);
  });

  test('kuota: mengikuti nilai server apa adanya', () {
    expect(SurplusFood.fromJson(_validFood(quota: 97)).quota, 97);
  });

  test('model valid: quota 0 dianggap tidak tersedia', () {
    final food = SurplusFood.fromJson(_validFood(quota: 0));

    expect(food.quota, 0);
    expect(food.isAvailable, isFalse);
  });

  test('model valid: nonaktif dianggap tidak tersedia', () {
    final food = SurplusFood.fromJson(_validFood(quota: 5, isActive: false));

    expect(food.isAvailable, isFalse);
  });

  // ============================================================
  // 2. MODEL INVALID
  // ============================================================
  test('model invalid: nama kosong melempar ApiException', () {
    expect(
      () => SurplusFood.fromJson(_validFood(name: '')),
      throwsA(isA<ApiException>()),
    );
  });

  test('model invalid: harga bukan int melempar ApiException', () {
    final json = _validFood();
    json['originalPrice'] = 'mahal';

    expect(
      () => SurplusFood.fromJson(json),
      throwsA(isA<ApiException>()),
    );
  });

  test('model invalid: field id tidak ada melempar ApiException', () {
    final json = _validFood();
    json.remove('id');

    expect(
      () => SurplusFood.fromJson(json),
      throwsA(isA<ApiException>()),
    );
  });

  test('model invalid: pesanan tanpa pickupCode melempar ApiException', () {
    final json = _validOrder();
    json.remove('pickupCode');

    expect(
      () => Order.fromJson(json),
      throwsA(isA<ApiException>()),
    );
  });

  // ============================================================
  // 3. API SUKSES (GET katalog)
  // ============================================================
  test('API sukses: 200 + foods berisi data -> List<SurplusFood>', () async {
    final repo = ApiSurplusFoodRepository(
      api: _api(MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/foods');
        return _json({
          'foods': [
            _validFood(id: 16),
            _validFood(id: 17, name: 'Nasi Ayam'),
          ],
        });
      })),
    );

    final foods = await repo.fetchSurplusFoods();

    expect(foods, hasLength(2));
    expect(foods.first.name, 'Roti Gandum');
    expect(foods.last.name, 'Nasi Ayam');
  });

  test('API sukses: makanan kuota 0 difilter dari hasil', () async {
    final repo = ApiSurplusFoodRepository(
      api: _api(MockClient((_) async => _json({
            'foods': [
              _validFood(id: 16, quota: 5),
              _validFood(id: 17, name: 'Habis', quota: 0),
            ],
          }))),
    );

    final foods = await repo.fetchSurplusFoods();

    expect(foods, hasLength(1));
    expect(foods.single.name, 'Roti Gandum');
  });

  // ============================================================
  // 4. DATA KOSONG
  // ============================================================
  test('data kosong: foods [] menghasilkan list kosong (bukan error)',
      () async {
    final repo = ApiSurplusFoodRepository(
      api: _api(MockClient((_) async => _json({'foods': <dynamic>[]}))),
    );

    expect(await repo.fetchSurplusFoods(), isEmpty);
  });

  // ============================================================
  // 5. HTTP GAGAL
  // ============================================================
  test('HTTP gagal: status 500 melempar ApiException', () async {
    final repo = ApiSurplusFoodRepository(
      api: _api(
        MockClient((_) async => http.Response('Internal Server Error', 500)),
      ),
    );

    await expectLater(
      repo.fetchSurplusFoods(),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
      ),
    );
  });

  test('HTTP gagal: koneksi terputus melempar ApiException', () async {
    final repo = ApiSurplusFoodRepository(
      api: _api(MockClient((_) async => throw http.ClientException('offline'))),
    );

    await expectLater(
      repo.fetchSurplusFoods(),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', null),
      ),
    );
  });

  // ============================================================
  // 6. JSON RUSAK
  // ============================================================
  test('JSON rusak: body bukan JSON melempar ApiException', () async {
    final repo = ApiSurplusFoodRepository(
      api: _api(
        MockClient((_) async => http.Response('<html>not json</html>', 200)),
      ),
    );

    await expectLater(repo.fetchSurplusFoods(), throwsA(isA<ApiException>()));
  });

  test('JSON rusak: struktur tanpa "foods" melempar ApiException', () async {
    final repo = ApiSurplusFoodRepository(
      api: _api(MockClient((_) async => _json({'data': []}))),
    );

    await expectLater(repo.fetchSurplusFoods(), throwsA(isA<ApiException>()));
  });

  // ============================================================
  // POST pesanan (harga dihitung server)
  // ============================================================
  test('POST sukses: hanya foodId + quantity yang dikirim', () async {
    final repo = ApiOrderRepository(
      api: _api(MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/orders');
        expect(request.headers['Authorization'], 'Bearer token-abc');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, {'foodId': 16, 'quantity': 2});
        // Klien tidak boleh mengirim totalPrice/unitPrice.
        expect(body.containsKey('totalPrice'), isFalse);

        return _json({'order': _validOrder()}, 201);
      })),
    );

    final order = await repo.createOrder(
      token: 'token-abc',
      foodId: 16,
      quantity: 2,
    );

    expect(order.id, 42);
    expect(order.pickupCode, 'RESCUE-7KQ2XM');
    expect(order.totalPrice, 30000);
    expect(order.status, OrderStatus.pending);
    expect(order.surplusFoodName, 'Roti Gandum');
  });

  test('POST gagal: 422 kuota tidak cukup -> pesan server dipakai', () async {
    final repo = ApiOrderRepository(
      api: _api(MockClient((_) async => _json({
            'error': {
              'code': 'insufficient_quota',
              'message': 'Sisa porsi tidak mencukupi.',
            },
          }, 422))),
    );

    await expectLater(
      repo.createOrder(token: 'token-abc', foodId: 16, quantity: 99),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Sisa porsi tidak mencukupi.')
            .having((e) => e.statusCode, 'statusCode', 422),
      ),
    );
  });

  test('complete mengirim pickupCode ke endpoint yang benar', () async {
    final repo = ApiOrderRepository(
      api: _api(MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/orders/42/complete');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['pickupCode'], 'RESCUE-7KQ2XM');
        return _json({'order': _validOrder(status: 'completed')});
      })),
    );

    final order = await repo.complete(
      token: 'token-merchant',
      orderId: 42,
      pickupCode: 'RESCUE-7KQ2XM',
    );

    expect(order.status, OrderStatus.completed);
  });

  test('cancel memindahkan status ke cancelled', () async {
    final repo = ApiOrderRepository(
      api: _api(MockClient((request) async {
        expect(request.url.path, '/orders/42/cancel');
        return _json({'order': _validOrder(status: 'cancelled')});
      })),
    );

    final order = await repo.cancel(token: 'token-abc', orderId: 42);

    expect(order.status, OrderStatus.cancelled);
  });
}
