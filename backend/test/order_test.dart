import 'package:food_rescue_backend/db/database.dart';
import 'package:food_rescue_backend/middleware/api_response.dart';
import 'package:test/test.dart';

import 'food_test.dart' show CatalogFixture;
import 'support.dart';

void main() {
  configureDriftForTests();
  late TestApi api;
  late CatalogFixture fixture;
  late String merchantToken;
  late int foodId;

  setUp(() async {
    api = TestApi();
    fixture = CatalogFixture(api);
    (merchantToken, _) = await fixture.merchant();
    foodId = await fixture.food(merchantToken, quota: 5);
  });
  tearDown(() => api.close());

  Future<int> quotaOf(int id) async {
    final row = await (api.db.select(api.db.surplusFoods)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    return row.quota;
  }

  group('POST /orders', () {
    test('201 + kuota berkurang + kode pick-up unik', () async {
      final (buyerToken, buyer, _) = await registerAndLogin(api);

      final response = await api.request('POST', '/orders', token: buyerToken, body: {
        'foodId': foodId,
        'quantity': 2,
      });

      final body = await api.json(response);
      expect(response.statusCode, 201, reason: body.toString());
      final order = body['order'] as Map<String, dynamic>;

      expect(order['quantity'], 2);
      expect(order['totalPrice'], 16000); // 8000 × 2
      expect(order['status'], 'pending');
      expect(order['pickupCode'], startsWith('RESCUE-'));
      expect(order['foodName'], 'Roti Sisa');
      expect(order['merchantName'], 'Warung Bu Siti');
      expect(order['buyerName'], buyer['name']);

      expect(await quotaOf(foodId), 3, reason: '5 - 2 = 3');
    });

    test('quantity melebihi kuota → 409, kuota TIDAK berubah', () async {
      final (buyerToken, _, _) = await registerAndLogin(api);

      final response = await api.request('POST', '/orders', token: buyerToken, body: {
        'foodId': foodId,
        'quantity': 6,
      });

      expect(response.statusCode, 409);
      expect(
        ((await api.json(response))['error'] as Map)['code'],
        'insufficient_quota',
      );
      expect(await quotaOf(foodId), 5);
      expect(await api.db.select(api.db.orders).get(), isEmpty);
    });

    test('quantity 0 / negatif / bukan int → 422', () async {
      final (buyerToken, _, _) = await registerAndLogin(api);

      for (final qty in [0, -1, '2', 2.5, true]) {
        final response =
            await api.request('POST', '/orders', token: buyerToken, body: {
          'foodId': foodId,
          'quantity': qty,
        });
        expect(response.statusCode, 422, reason: 'quantity=$qty');
      }
      expect(await quotaOf(foodId), 5);
    });

    test('makanan nonaktif → 404 (tidak bisa dipesan)', () async {
      await api.request('DELETE', '/foods/$foodId', token: merchantToken);

      final (buyerToken, _, _) = await registerAndLogin(api);
      final response = await api.request('POST', '/orders', token: buyerToken, body: {
        'foodId': foodId,
        'quantity': 1,
      });
      expect(response.statusCode, 404);
    });

    test('merchant / admin tidak bisa memesan (bukan buyer) → 403', () async {
      final response = await api.request('POST', '/orders', token: merchantToken, body: {
        'foodId': foodId,
        'quantity': 1,
      });
      expect(response.statusCode, 403);
    });

    /// Test paling penting sesi ini: tidak ada kuota minus.
    test('DUA pembeli berebut unit terakhir → satu 201, satu 409', () async {
      final single = await fixture.food(merchantToken, name: 'Porsi Terakhir', quota: 1);

      final (buyerA, _, _) =
          await registerAndLogin(api, email: 'a@example.com');
      final (buyerB, _, _) =
          await registerAndLogin(api, email: 'b@example.com');

      final results = await Future.wait([
        api.request('POST', '/orders', token: buyerA, body: {
          'foodId': single,
          'quantity': 1,
        }),
        api.request('POST', '/orders', token: buyerB, body: {
          'foodId': single,
          'quantity': 1,
        }),
      ]);

      final codes = results.map((r) => r.statusCode).toList()..sort();
      expect(codes, [201, 409], reason: 'kode: $codes');

      expect(await quotaOf(single), 0, reason: 'kuota tidak boleh minus');
      expect(await api.db.select(api.db.orders).get(), hasLength(1));
    });

    test('20 request paralel untuk kuota 5 → tepat 5 pesanan', () async {
      final target = await fixture.food(merchantToken, name: 'Berebut', quota: 5);

      final tokens = <String>[];
      for (var i = 0; i < 20; i++) {
        final (token, _, _) =
            await registerAndLogin(api, email: 'p$i@example.com');
        tokens.add(token);
      }

      final results = await Future.wait([
        for (final token in tokens)
          api.request('POST', '/orders', token: token, body: {
            'foodId': target,
            'quantity': 1,
          }),
      ]);

      final ok = results.where((r) => r.statusCode == 201).length;
      final conflict = results.where((r) => r.statusCode == 409).length;

      expect(ok, 5, reason: 'hanya 5 yang boleh lolos');
      expect(conflict, 15);
      expect(await quotaOf(target), 0);
      expect(await api.db.select(api.db.orders).get(), hasLength(5));
    });
  });

  group('GET /orders — isolasi antar pemilik', () {
    test('buyer hanya melihat pesanannya sendiri', () async {
      final (buyerA, _, _) =
          await registerAndLogin(api, email: 'a@example.com');
      final (buyerB, _, _) =
          await registerAndLogin(api, email: 'b@example.com');

      await api.request('POST', '/orders', token: buyerA, body: {
        'foodId': foodId,
        'quantity': 1,
      });
      await api.request('POST', '/orders', token: buyerB, body: {
        'foodId': foodId,
        'quantity': 1,
      });

      final bodyA = await api.json(
        await api.request('GET', '/orders', token: buyerA),
      );
      expect(bodyA['count'], 1);
      expect(((bodyA['orders'] as List).single as Map)['buyerId'], isNotNull);
    });

    test('merchant melihat pesanan di tokonya saja', () async {
      final (otherToken, _) = await fixture.merchant(
        email: 'other@example.com',
        storeName: 'Toko Lain',
      );
      final otherFood = await fixture.food(otherToken, name: 'Kue Lain');

      final (buyer, _, _) = await registerAndLogin(api);
      await api.request('POST', '/orders', token: buyer, body: {
        'foodId': foodId,
        'quantity': 1,
      });
      await api.request('POST', '/orders', token: buyer, body: {
        'foodId': otherFood,
        'quantity': 1,
      });

      final body = await api.json(
        await api.request('GET', '/orders', token: merchantToken),
      );
      expect(body['count'], 1);
      expect(
        ((body['orders'] as List).single as Map)['foodId'],
        foodId,
      );
    });

    test('GET /orders/<id> pesanan orang lain → 404', () async {
      final (buyer, _, _) = await registerAndLogin(api);
      final created = await api.json(await api.request(
        'POST',
        '/orders',
        token: buyer,
        body: {'foodId': foodId, 'quantity': 1},
      ));
      final orderId = (created['order'] as Map)['id'];

      final (lain, _, _) = await registerAndLogin(api, email: 'lain@example.com');
      expect(
        (await api.request('GET', '/orders/$orderId', token: lain)).statusCode,
        404,
      );
    });

    test('tanpa token → 401', () async {
      expect((await api.request('GET', '/orders')).statusCode, 401);
    });
  });

  group('POST /orders/<id>/complete', () {
    late int orderId;
    late String pickupCode;
    late String buyerToken;

    setUp(() async {
      final (token, _, _) = await registerAndLogin(api);
      buyerToken = token;

      final body = await api.json(await api.request(
        'POST',
        '/orders',
        token: buyerToken,
        body: {'foodId': foodId, 'quantity': 1},
      ));
      final order = body['order'] as Map<String, dynamic>;
      orderId = order['id'] as int;
      pickupCode = order['pickupCode'] as String;
    });

    test('kode benar → completed', () async {
      final response = await api.request(
        'POST',
        '/orders/$orderId/complete',
        token: merchantToken,
        body: {'pickupCode': pickupCode},
      );

      expect(response.statusCode, 200);
      expect(((await api.json(response))['order'] as Map)['status'], 'completed');
    });

    test('kode salah → 422, status tetap pending', () async {
      final response = await api.request(
        'POST',
        '/orders/$orderId/complete',
        token: merchantToken,
        body: {'pickupCode': 'RESCUE-SALAHXXX'},
      );
      expect(response.statusCode, 422);

      final row = await (api.db.select(api.db.orders)
            ..where((t) => t.id.equals(orderId)))
          .getSingle();
      expect(row.status, OrderStatus.pending);
    });

    test('tanpa pickupCode → 422 (tidak bisa menebak tombol)', () async {
      final response = await api.request(
        'POST',
        '/orders/$orderId/complete',
        token: merchantToken,
        body: const {},
      );
      expect(response.statusCode, 422);
    });

    test('buyer tidak boleh menandai completed sendiri → 403', () async {
      final response = await api.request(
        'POST',
        '/orders/$orderId/complete',
        token: buyerToken,
        body: {'pickupCode': pickupCode},
      );
      expect(response.statusCode, 403);
    });

    test('merchant toko lain → 404', () async {
      final (other, _) = await fixture.merchant(
        email: 'other@example.com',
        storeName: 'Toko Lain',
      );

      final response = await api.request(
        'POST',
        '/orders/$orderId/complete',
        token: other,
        body: {'pickupCode': pickupCode},
      );
      expect(response.statusCode, 404);
    });

    test('completed dua kali → 409', () async {
      await api.request(
        'POST',
        '/orders/$orderId/complete',
        token: merchantToken,
        body: {'pickupCode': pickupCode},
      );

      final again = await api.request(
        'POST',
        '/orders/$orderId/complete',
        token: merchantToken,
        body: {'pickupCode': pickupCode},
      );
      expect(again.statusCode, 409);
    });
  });

  group('POST /orders/<id>/cancel', () {
    test('buyer batal → kuota kembali', () async {
      final (buyer, _, _) = await registerAndLogin(api);

      final created = await api.json(await api.request(
        'POST',
        '/orders',
        token: buyer,
        body: {'foodId': foodId, 'quantity': 3},
      ));
      final orderId = (created['order'] as Map)['id'];
      expect(await quotaOf(foodId), 2);

      final response = await api.request(
        'POST',
        '/orders/$orderId/cancel',
        token: buyer,
      );
      expect(response.statusCode, 200);
      expect(((await api.json(response))['order'] as Map)['status'], 'cancelled');
      expect(await quotaOf(foodId), 5, reason: 'kuota kembali penuh');
    });

    test('pesanan completed tidak bisa dibatalkan → 409', () async {
      final (buyer, _, _) = await registerAndLogin(api);
      final created = await api.json(await api.request(
        'POST',
        '/orders',
        token: buyer,
        body: {'foodId': foodId, 'quantity': 1},
      ));
      final order = created['order'] as Map<String, dynamic>;

      await api.request(
        'POST',
        '/orders/${order['id']}/complete',
        token: merchantToken,
        body: {'pickupCode': order['pickupCode']},
      );

      final response = await api.request(
        'POST',
        '/orders/${order['id']}/cancel',
        token: buyer,
      );
      expect(response.statusCode, 409);
      expect(await quotaOf(foodId), 4, reason: 'tidak boleh bertambah lagi');
    });

    test('buyer lain tidak bisa membatalkan → 404', () async {
      final (buyer, _, _) = await registerAndLogin(api);
      final created = await api.json(await api.request(
        'POST',
        '/orders',
        token: buyer,
        body: {'foodId': foodId, 'quantity': 1},
      ));

      final (lain, _, _) = await registerAndLogin(api, email: 'lain@example.com');
      final response = await api.request(
        'POST',
        '/orders/${(created['order'] as Map)['id']}/cancel',
        token: lain,
      );
      expect(response.statusCode, 404);
    });

    test('batal dua kali → 409 dan kuota tidak dobel', () async {
      final (buyer, _, _) = await registerAndLogin(api);
      final created = await api.json(await api.request(
        'POST',
        '/orders',
        token: buyer,
        body: {'foodId': foodId, 'quantity': 2},
      ));
      final orderId = (created['order'] as Map)['id'];

      await api.request('POST', '/orders/$orderId/cancel', token: buyer);
      final second =
          await api.request('POST', '/orders/$orderId/cancel', token: buyer);

      expect(second.statusCode, 409);
      expect(await quotaOf(foodId), 5, reason: '5, bukan 7');
    });

    test('pesanan tidak pernah dihapus dari DB', () async {
      final (buyer, _, _) = await registerAndLogin(api);
      final created = await api.json(await api.request(
        'POST',
        '/orders',
        token: buyer,
        body: {'foodId': foodId, 'quantity': 1},
      ));
      final orderId = (created['order'] as Map)['id'];

      await api.request('POST', '/orders/$orderId/cancel', token: buyer);

      final rows = await api.db.select(api.db.orders).get();
      expect(rows, hasLength(1));
      expect(rows.single.status, OrderStatus.cancelled);
    });
  });

  group('kebocoran data', () {
    test('pesanan tidak pernah memuat data user sensitif', () async {
      final (buyer, _, _) = await registerAndLogin(api);
      final body = await api.json(await api.request(
        'POST',
        '/orders',
        token: buyer,
        body: {'foodId': foodId, 'quantity': 1},
      ));

      final text = body.toString();
      expect(text.contains('passwordHash'), isFalse);
      expect(text.contains(r'$2a$'), isFalse);
      expect(text.toLowerCase().contains('email'), isFalse);
    });

    test('pickupCode tidak muncul di log', () async {
      final (buyer, _, _) = await registerAndLogin(api);
      final body = await api.json(await api.request(
        'POST',
        '/orders',
        token: buyer,
        body: {'foodId': foodId, 'quantity': 1},
      ));
      final code = (body['order'] as Map)['pickupCode'] as String;

      expect(api.logs.join('\n').contains(code), isFalse);
    });
  });

  group('validasi input helper', () {
    test('requireInt menolak tipe selain int', () {
      for (final value in ['1', 1.0, true, null]) {
        expect(
          () => requireInt({'n': value}, 'n', min: 1, max: 5),
          throwsA(isA<ApiException>()),
          reason: '$value',
        );
      }
    });

    test('requireInt menolak di luar batas', () {
      expect(
        () => requireInt({'n': 0}, 'n', min: 1, max: 5),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => requireInt({'n': 6}, 'n', min: 1, max: 5),
        throwsA(isA<ApiException>()),
      );
      expect(requireInt({'n': 5}, 'n', min: 1, max: 5), 5);
    });
  });
}
