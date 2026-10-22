// P6: Unit test Integrasi API & Model.
//
// Minimal 6 skenario yang diminta:
//   1. model valid
//   2. model invalid
//   3. API sukses
//   4. data kosong
//   5. HTTP gagal
//   6. JSON rusak
//
// Catatan: semua test memakai MockClient (in-memory) sehingga tidak butuh
// koneksi internet dan hasilnya deterministik.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_rescue_app/models/order_model.dart';
import 'package:food_rescue_app/models/surplus_food_model.dart';
import 'package:food_rescue_app/repositories/order_repository.dart';
import 'package:food_rescue_app/repositories/surplus_food_repository.dart';

/// Satu produk valid sesuai kontrak dummyjson.
Map<String, dynamic> _validProduct({
  int id = 16,
  String title = 'Apple',
  num price = 1.99,
  int stock = 8,
}) {
  return {
    'id': id,
    'title': title,
    'description': 'Fresh and crisp apples.',
    'category': 'groceries',
    'price': price,
    'discountPercentage': 12.62,
    'rating': 4.19,
    'stock': stock,
    'reviews': [
      {'rating': 5, 'comment': 'Enak'},
    ],
  };
}

http.Response _json(Object body, [int status = 200]) {
  return http.Response(jsonEncode(body), status,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

void main() {
  // ============================================================
  // 1. MODEL VALID
  // ============================================================
  test('model valid: SurplusFood.fromJson memetakan semua field', () {
    final food = SurplusFood.fromJson(_validProduct());

    expect(food.id, '16');
    expect(food.name, 'Apple');
    expect(food.category, FoodCategory.main);
    expect(food.originalPrice, (1.99 * 16000).round());
    // Stok API (8) dipotong ke batas wajar kategori makanan berat (maks 10).
    expect(food.quota, inInclusiveRange(1, SurplusFood.quotaCeiling(FoodCategory.main)));
    expect(food.isAvailable, isTrue);
    expect(food.rating, 4.19);
    expect(food.sold, 1); // jumlah review
  });

  test('kuota: stok besar (97) dipotong ke batas logis per kategori', () {
    final food = SurplusFood.fromJson(_validProduct(stock: 97));

    expect(food.quota, lessThanOrEqualTo(10));
    expect(food.quota, greaterThan(0));
  });

  test('model valid: quota 0 dianggap tidak tersedia', () {
    final food = SurplusFood.fromJson(_validProduct(stock: 0));

    expect(food.quota, 0);
    expect(food.isAvailable, isFalse);
  });

  // ============================================================
  // 2. MODEL INVALID
  // ============================================================
  test('model invalid: title kosong melempar InvalidModelException', () {
    expect(
      () => SurplusFood.fromJson(_validProduct(title: '')),
      throwsA(isA<InvalidModelException>()),
    );
  });

  test('model invalid: price bukan angka melempar InvalidModelException', () {
    final json = _validProduct();
    json['price'] = 'mahal';

    expect(
      () => SurplusFood.fromJson(json),
      throwsA(isA<InvalidModelException>()),
    );
  });

  test('model invalid: field id tidak ada melempar InvalidModelException', () {
    final json = _validProduct();
    json.remove('id');

    expect(
      () => SurplusFood.fromJson(json),
      throwsA(isA<InvalidModelException>()),
    );
  });

  // ============================================================
  // 3. API SUKSES (GET katalog)
  // ============================================================
  test('API sukses: 200 + products berisi data -> List<SurplusFood>', () async {
    final repo = ApiSurplusFoodRepository(
      client: MockClient((request) async {
        expect(request.url.host, 'dummyjson.com');
        expect(request.method, 'GET');
        return _json({
          'products': [_validProduct(id: 16), _validProduct(id: 17, title: 'Beef Steak')],
          'total': 2,
        });
      }),
    );

    final foods = await repo.fetchSurplusFoods();

    expect(foods, hasLength(2));
    expect(foods.first.name, 'Apple');
    expect(foods.last.name, 'Beef Steak');
  });

  test('API sukses: produk dengan stok 0 difilter dari hasil', () async {
    final repo = ApiSurplusFoodRepository(
      client: MockClient((_) async => _json({
            'products': [
              _validProduct(stock: 5),
              _validProduct(id: 17, title: 'Habis', stock: 0),
            ],
          })),
    );

    final foods = await repo.fetchSurplusFoods();

    expect(foods, hasLength(1));
    expect(foods.single.name, 'Apple');
  });

  // ============================================================
  // 4. DATA KOSONG
  // ============================================================
  test('data kosong: products [] menghasilkan list kosong (bukan error)',
      () async {
    final repo = ApiSurplusFoodRepository(
      client: MockClient((_) async => _json({'products': <dynamic>[], 'total': 0})),
    );

    expect(await repo.fetchSurplusFoods(), isEmpty);
  });

  // ============================================================
  // 5. HTTP GAGAL
  // ============================================================
  test('HTTP gagal: status 500 melempar ApiException', () async {
    final repo = ApiSurplusFoodRepository(
      client: MockClient((_) async => http.Response('Internal Server Error', 500)),
    );

    expect(
      () => repo.fetchSurplusFoods(),
      throwsA(isA<ApiException>()),
    );
  });

  test('HTTP gagal: koneksi terputus melempar ApiException', () async {
    final repo = ApiSurplusFoodRepository(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );

    expect(
      () => repo.fetchSurplusFoods(),
      throwsA(isA<ApiException>()),
    );
  });

  // ============================================================
  // 6. JSON RUSAK
  // ============================================================
  test('JSON rusak: body bukan JSON melempar ApiException', () async {
    final repo = ApiSurplusFoodRepository(
      client: MockClient((_) async => http.Response('<html>not json</html>', 200)),
    );

    expect(
      () => repo.fetchSurplusFoods(),
      throwsA(isA<ApiException>()),
    );
  });

  test('JSON rusak: struktur tanpa "products" melempar ApiException', () async {
    final repo = ApiSurplusFoodRepository(
      client: MockClient((_) async => _json({'data': []})),
    );

    expect(
      () => repo.fetchSurplusFoods(),
      throwsA(isA<ApiException>()),
    );
  });

  // ============================================================
  // POST pesanan (vertical slice: simpan ke backend)
  // ============================================================
  test('POST sukses: pesanan tersimpan di backend, PickupCode dari server id',
      () async {
    final repo = ApiOrderRepository(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['products'][0]['quantity'], 2);
        return http.Response(jsonEncode({'id': 209, 'total': 3.98}), 201);
      }),
    );

    final order = await repo.createOrder(
      buyerName: 'William',
      surplusFoodId: '16',
      surplusFoodName: 'Apple',
      quantity: 2,
      unitPrice: 5000,
    );

    expect(order.id, startsWith('ord-209-'));
    expect(order.pickupCode, startsWith('RESCUE-209-'));
    expect(order.totalPrice, 10000);
    expect(order.status, OrderStatus.pending);
  });

  test('POST: dua pesanan berurutan menghasilkan id berbeda (tidak tabrakan)',
      () async {
    final repo = ApiOrderRepository(
      client: MockClient((_) async {
        // dummyjson selalu mengembalikan id 209 untuk setiap POST.
        return http.Response(jsonEncode({'id': 209}), 201);
      }),
    );

    final first = await repo.createOrder(
      buyerName: 'A',
      surplusFoodId: '16',
      surplusFoodName: 'Apple',
      quantity: 1,
      unitPrice: 1000,
    );
    final second = await repo.createOrder(
      buyerName: 'B',
      surplusFoodId: '17',
      surplusFoodName: 'Beef',
      quantity: 1,
      unitPrice: 1000,
    );

    expect(first.id, isNot(second.id));
    expect(first.pickupCode, isNot(second.pickupCode));
  });

  test('POST gagal: status 400 melempar ApiException', () async {
    final repo = ApiOrderRepository(
      client: MockClient((_) async => http.Response('Bad Request', 400)),
    );

    expect(
      () => repo.createOrder(
        buyerName: 'William',
        surplusFoodId: '16',
        surplusFoodName: 'Apple',
        quantity: 1,
        unitPrice: 5000,
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('POST JSON rusak: body bukan JSON melempar ApiException', () async {
    final repo = ApiOrderRepository(
      client: MockClient((_) async => http.Response('oops', 201)),
    );

    expect(
      () => repo.createOrder(
        buyerName: 'William',
        surplusFoodId: '16',
        surplusFoodName: 'Apple',
        quantity: 1,
        unitPrice: 5000,
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
