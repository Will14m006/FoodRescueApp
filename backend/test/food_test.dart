import 'package:food_rescue_backend/orders/pickup_code.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Helper khusus sesi 3: menyiapkan merchant + toko + makanan.
class CatalogFixture {
  CatalogFixture(this.api);

  final TestApi api;

  /// Daftarkan merchant, buat toko, kembalikan (token, merchantId).
  Future<(String, int)> merchant({
    String email = 'toko@example.com',
    String storeName = 'Warung Bu Siti',
  }) async {
    final (token, _, _) = await registerAndLogin(
      api,
      email: email,
      role: 'merchant',
    );

    final response = await api.request(
      'PUT',
      '/merchants/me',
      token: token,
      body: {'storeName': storeName},
    );
    expect(response.statusCode, 200);

    final body = await api.json(response);
    return (token, (body['merchant'] as Map)['id'] as int);
  }

  /// Buat makanan, kembalikan id-nya.
  Future<int> food(
    String token, {
    String name = 'Roti Sisa',
    int quota = 5,
    int originalPrice = 20000,
    int discountPrice = 8000,
    String pickupWindow = '19:00 - 21:00',
  }) async {
    final response = await api.request('POST', '/foods', token: token, body: {
      'name': name,
      'description': 'Layak makan, sisa hari ini.',
      'originalPrice': originalPrice,
      'discountPrice': discountPrice,
      'quota': quota,
      'pickupWindow': pickupWindow,
    });
    // Body dibaca sekali saja; `reason` tidak boleh membaca stream.
    final body = await api.json(response);
    expect(response.statusCode, 201, reason: body.toString());
    return (body['food'] as Map)['id'] as int;
  }
}

void main() {
  configureDriftForTests();
  group('PickupCode', () {
    test('format RESCUE- diikuti 8 karakter alfabet aman', () {
      final code = PickupCode.generate();
      expect(RegExp(r'^RESCUE-[A-HJ-NP-Z2-9]{8}$').hasMatch(code), isTrue,
          reason: code);
    });

    test('tidak pernah memakai 0/O/1/I/L (salah baca)', () {
      for (var i = 0; i < 200; i++) {
        final suffix = PickupCode.generate().substring(7);
        expect(suffix.contains('0'), isFalse);
        expect(suffix.contains('O'), isFalse);
        expect(suffix.contains('1'), isFalse);
        expect(suffix.contains('I'), isFalse);
        expect(suffix.contains('L'), isFalse);
      }
    });

    test('1000 kode berturut-turut tidak ada yang sama', () {
      final codes = {for (var i = 0; i < 1000; i++) PickupCode.generate()};
      expect(codes, hasLength(1000));
    });
  });

  group('POST /foods', () {
    late TestApi api;
    late CatalogFixture fixture;
    setUp(() {
      api = TestApi();
      fixture = CatalogFixture(api);
    });
    tearDown(() => api.close());

    test('merchant tanpa profil toko → 409', () async {
      final (token, _, _) = await registerAndLogin(
        api,
        email: 'tanpa-toko@example.com',
        role: 'merchant',
      );

      final response = await api.request('POST', '/foods', token: token, body: {
        'name': 'X',
        'originalPrice': 10000,
        'discountPrice': 5000,
        'quota': 3,
        'pickupWindow': '19:00 - 21:00',
      });
      expect(response.statusCode, 409);
    });

    test('buyer tidak boleh membuat makanan → 403', () async {
      final (token, _, _) = await registerAndLogin(api);

      final response = await api.request('POST', '/foods', token: token, body: {
        'name': 'X',
        'originalPrice': 10000,
        'discountPrice': 5000,
        'quota': 3,
        'pickupWindow': '19:00 - 21:00',
      });
      expect(response.statusCode, 403);
    });

    test('harga diskon > harga asli → 422', () async {
      final (token, _) = await fixture.merchant();

      final response = await api.request('POST', '/foods', token: token, body: {
        'name': 'Mahal',
        'originalPrice': 5000,
        'discountPrice': 9000,
        'quota': 3,
        'pickupWindow': '19:00 - 21:00',
      });
      expect(response.statusCode, 422);
    });

    test('harga negatif / nol → 422', () async {
      final (token, _) = await fixture.merchant();

      for (final price in [0, -1000]) {
        final response =
            await api.request('POST', '/foods', token: token, body: {
          'name': 'X',
          'originalPrice': price,
          'discountPrice': price,
          'quota': 3,
          'pickupWindow': '19:00 - 21:00',
        });
        expect(response.statusCode, 422, reason: 'harga $price');
      }
    });

    test('harga berupa teks → 422 (tidak ditebak)', () async {
      final (token, _) = await fixture.merchant();

      final response = await api.request('POST', '/foods', token: token, body: {
        'name': 'X',
        'originalPrice': '10000',
        'discountPrice': 5000,
        'quota': 3,
        'pickupWindow': '19:00 - 21:00',
      });
      expect(response.statusCode, 422);
    });

    test('stok besar (10000) diterima', () async {
      final (token, _) = await fixture.merchant();
      final id = await fixture.food(token, quota: 10000);
      expect(id, greaterThan(0));
    });
  });

  group('GET /foods — katalog publik', () {
    late TestApi api;
    late CatalogFixture fixture;
    setUp(() {
      api = TestApi();
      fixture = CatalogFixture(api);
    });
    tearDown(() => api.close());

    test('tanpa token tetap 200 (publik)', () async {
      final (token, _) = await fixture.merchant();
      await fixture.food(token, name: 'Nasi Goreng');

      final response = await api.request('GET', '/foods');
      expect(response.statusCode, 200);

      final body = await api.json(response);
      expect(body['count'], 1);
      final food = (body['foods'] as List).single as Map<String, dynamic>;
      expect(food['name'], 'Nasi Goreng');
      expect(food['merchantName'], 'Warung Bu Siti');
    });

    test('makanan nonaktif / kuota 0 tidak muncul', () async {
      final (token, _) = await fixture.merchant();
      final habis = await fixture.food(token, name: 'Habis', quota: 1);
      await fixture.food(token, name: 'Ada', quota: 4);

      // Habiskan yang pertama lewat jalur resmi (bukan UPDATE langsung).
      final (buyerToken, _, _) = await registerAndLogin(api);
      await api.request('POST', '/orders', token: buyerToken, body: {
        'foodId': habis,
        'quantity': 1,
      });

      final body = await api.json(await api.request('GET', '/foods'));
      final names = (body['foods'] as List)
          .map((f) => (f as Map)['name'])
          .toList();
      expect(names, ['Ada']);
    });

    test('pencarian `q` cocok pada nama makanan dan nama toko', () async {
      final (token, _) = await fixture.merchant(storeName: 'Bakery Senja');
      await fixture.food(token, name: 'Croissant');
      await fixture.food(token, name: 'Roti Gandum');

      final byFood = await api.json(
        await api.request('GET', '/foods?q=crois'),
      );
      expect(byFood['count'], 1);

      final byStore = await api.json(
        await api.request('GET', '/foods?q=bakery'),
      );
      expect(byStore['count'], 2);
    });

    test('GET /foods/<id> tidak ada → 404 JSON', () async {
      final response = await api.request('GET', '/foods/999');
      expect(response.statusCode, 404);
      expect(
        ((await api.json(response))['error'] as Map)['code'],
        'not_found',
      );
    });

    test('GET /foods/abc → 404 (bukan 500)', () async {
      expect((await api.request('GET', '/foods/abc')).statusCode, 404);
    });
  });

  group('PATCH & DELETE /foods', () {
    late TestApi api;
    late CatalogFixture fixture;
    setUp(() {
      api = TestApi();
      fixture = CatalogFixture(api);
    });
    tearDown(() => api.close());

    test('merchant lain tidak bisa mengubah makanan orang → 404', () async {
      final (tokenA, _) = await fixture.merchant(email: 'a@example.com');
      final foodId = await fixture.food(tokenA);

      final (tokenB, _) = await fixture.merchant(
        email: 'b@example.com',
        storeName: 'Toko B',
      );

      final response = await api.request(
        'PATCH',
        '/foods/$foodId',
        token: tokenB,
        body: {'quota': 99},
      );
      expect(response.statusCode, 404);

      // Pastikan benar-benar tidak berubah.
      final body = await api.json(await api.request('GET', '/foods/$foodId'));
      expect((body['food'] as Map)['quota'], 5);
    });

    test('PATCH kuota memperbarui nilai', () async {
      final (token, _) = await fixture.merchant();
      final foodId = await fixture.food(token, quota: 5);

      final response = await api.request(
        'PATCH',
        '/foods/$foodId',
        token: token,
        body: {'quota': 12},
      );
      expect(response.statusCode, 200);
      expect(((await api.json(response))['food'] as Map)['quota'], 12);
    });

    test('DELETE = soft delete; baris tetap ada tapi hilang dari katalog',
        () async {
      final (token, _) = await fixture.merchant();
      final foodId = await fixture.food(token);

      final response =
          await api.request('DELETE', '/foods/$foodId', token: token);
      expect(response.statusCode, 200);
      expect(((await api.json(response))['food'] as Map)['isActive'], false);

      final catalog = await api.json(await api.request('GET', '/foods'));
      expect(catalog['count'], 0);

      // Baris masih ada di DB — pesanan lama tetap valid.
      final row = await (api.db.select(api.db.surplusFoods)
            ..where((t) => t.id.equals(foodId)))
          .getSingle();
      expect(row.isActive, isFalse);
    });
  });
}
